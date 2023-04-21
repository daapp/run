#! /bin/sh
# -*- mode: Tcl; -*- \
exec tclsh "$0" ${1+"$@"}

# (c) 2017-2021 Alexander Danilov <alexander.a.danilov@gmail.com>

package require Tk
package require Ttk
package require msgcat
namespace import msgcat::mc msgcat::mcset

catch {package require fsdialog}


array set config [list dir [file join $env(HOME) .config run]]
array set config {
    pager tkpager
    dict dict
    term stdout
}
set config(userCommandFile) [file join $config(dir) user_commands]
set config(userCommands)    [list [list Alt-d "dictionary" "$config(dict) '%s'"]]

# minimal number of characters for completion
set minCompletionSize 3

# Maximum size of history file
set historySize 20

# Maximum menu size
set completionMenuSize 30

set command ""


msgcat::mcset ru "run command" "выполнить команду"
msgcat::mcset ru "dictionary" "словарь"
msgcat::mcset ru "show history" "показать историю"
msgcat::mcset ru "completion (after 3 characters)" "дополнение (после 3х знаков)"
msgcat::mcset ru "exit" "выйти"
msgcat::mcset ru "Shell command" "Команда оболочки"
msgcat::mcset ru "Browse" "Обзор"


ttk::style configure TButton \
    -background lightblue \
    -foreground black \
    -padding {0 7} \
    -width -4
ttk::style map TButton \
    -background [list active lightblue] \
    -foreground [list disabled black]

proc main {} {
    variable config

    file mkdir $config(dir)

    ttk::label .l1 -text [mc "Shell command"]:
    ttk::entry .command \
        -textvariable command \
        -exportselection false
    button .browse \
        -text [mc Browse] \
        -underline 0 \
        -command {browse .command}

    ttk::separator .s1 -orient horizontal

    ttk::frame .help
    set font [font configure TkDefaultFont]
    dict set font -size [expr {int([dict get $font -size] * 0.8)}]
    set r 0
    foreach row {
        {⏎ "run command" Esc exit}
        {↓ "show history" ⭾ "completion (after 3 characters)"}
    } {
        set ws [list]
        set c1 0
        set c2 1
        foreach {key desc} $row {
            ttk::button .help.key$r$c1 -text $key -state disabled;# -font $font
            label .help.desc$r$c2 -text " - [mc $desc]." ;#-font $font
            lappend ws .help.key$r$c1 .help.desc$r$c2
            incr c1 2; incr c2 2
        }
        grid {*}$ws -sticky w -pady 3
        incr r
    }
    lappend config(userCommands) {*}[readUserCommands $config(userCommandFile)]
    if {$config(userCommands) ne ""} {
        frame .help.sep1 -height 2 -relief ridge -bd 1
        grid .help.sep1 - - - - -sticky ew -pady 10
        set i 0
        set table [list]
        set ws [list]
        foreach cmd $config(userCommands) {
            lassign $cmd binding description userCommand
            ttk::button .help.ukey$i -text $binding -state disabled
            label .help.udesc$i -text " - [mc $description]."
            switch -- [llength $ws] {
                0 {
                    lappend ws .help.ukey$i .help.udesc$i
                }
                2 {
                    lappend ws .help.ukey$i .help.udesc$i
                    lappend table $ws
                    set ws [list]
                }
                default {
                    set table [list]
                }
            }
            incr i
            bind .command <$binding> [list runUserCommand [string map {% %%} $userCommand]]
        }
        if {[llength $ws] != 0} {
            lappend table $ws
        }
        foreach row $table {
            grid {*}$row -sticky w -pady 3
        }
    }

    grid .l1 x .browse -sticky e -padx 5 -pady 2
    grid .command -row 0 -column 1 -sticky ew -padx 5 -pady 2

    grid .s1 - - -sticky ew -padx 5 -pady 5
    grid .help - - -sticky we -padx 5 -pady 5
    grid columnconfigure . .command -weight 2

    menu .historyMenu -tearoff 0
    menu .completionMenu -tearoff 0
    readMenu .historyMenu history [list]

    bind . <Escape> quit
    bind .command <Tab> [list completion .completionMenu .command]
    bind .command <Key-Return> {run history}
    bind .command <Key-Down> {
        if {$command ne ""} {
            .completionMenu activate 0
            after idle focus .completionMenu
        } else {
            .historyMenu post [winfo rootx .command] [expr {[winfo rooty .command] + [winfo height .command]}]
            after idle focus .historyMenu
        }
    }
    bind .historyMenu <Unmap> {
        after idle {
            focus -force .command
            .command icursor end
        }
    }
    bind .completionMenu <Escape> {
        %W unpost
        after idle {focus -force .command}
    }
    bind .completionMenu <Unmap> {
        after idle {
            focus -force .command
            .command icursor end
        }
    }
    bind . <Map> {wm geometry . [winfo reqwidth .]x[winfo reqheight .]}
    bind . <Alt-b> {.browse invoke}

    wm title . Run
    wm positionfrom . program
    wm resizable . 0 0

    tk app Run
    focus -force .command
}


proc quit {} {
    destroy .
    exit 0
}

#
# Pops up standard file selection dialog and inserts selected file into
# command line. Note - not only as command, but as argument as well
#
proc browse {command} {
    set name [tk_getOpenFile ]
    if {"$name" == ""} return

    if [$command selection present] {
        $command delete sel.first sel.last
        $command insert sel.first $name
    } else {
        $command insert insert $name
    }
    focus $command
    $command xview end
}


# read file in format:
#   binding description command
proc readUserCommands {fileName} {
    variable config

    set userCommands [list]
    if {![catch {set f [open [file join $fileName] r]} e]} {
        while {![chan eof $f]} {
            set s [string trim [chan gets $f]]
            if {$s ne ""} {
                lappend userCommands $s
            }
        }
        chan close $f
    }
    return $userCommands
}

#
# Runs desired command and records it in the history file
#
proc run {name} {
    variable command
    variable config

    set command [string trim $command]
    if {$command ne ""} {
        exec /bin/sh -c $command >/dev/$config(term) </dev/$config(term) 2>/dev/$config(term) &
        set f [open [file join $config(dir) .run_$name] a+]
        puts $f $command
        close $f
    }
    quit
}


proc runUserCommand {userCommand} {
    variable command
    variable config

    set word [string trim $command]
    if {$word ne ""} {
        exec $::env(SHELL) -c [format "$userCommand | $config(pager)" $word] &
    }
    quit
}


proc readMenu {menu name defaultValues} {
    variable historySize config

    if {[catch {open [file join $config(dir) .run_$name] r} f]} {
        foreach v $defaultValues {
            $menu add command -label $v -command [list set command $v]
        }
    } else {
        set list {}
        while {![eof $f]} {
            set entry [gets $f]
            if {![string length $entry]} continue
            set list [linsert $list 0 $entry]
        }
        close $f
        if {[llength $list] > $historySize} {
            set list [lreplace $list $historySize end]
            set f [open [file join $config(dir) .run_$name] w]
            foreach h [lrange $list 0 $historySize] {
                puts $f $h
            }
            close $f
        }
        foreach entry $list {
            $menu add command -label $entry -command [list set command $entry]
        }
    }
}


proc completion {menuName command} {
    global minCompletionSize

    set text [$command get]
    if {[string length $text] >= $minCompletionSize} {
        $menuName delete 0 end
        package require fileutil
        set found [list]
        foreach path [split $::env(PATH) :] {
            if {[file isdirectory $path]} {
                foreach file [fileutil::findByPattern $path -glob $text*] {
                    lappend found [lindex [file split $file] end]
                }
            }
        }
        if {[llength $found] > 0} {
            if {[llength $found] == 1} {
                set ::command [lindex $found 0]
                $command icursor end
            } else {
                foreach file [lrange $found 0 [expr {$::completionMenuSize - 1}]] {
                    $menuName add command -label $file -command [list set command $file]
                }
                if {[llength $found] > $::completionMenuSize} {
                    $menuName add command -label "[expr {[llength $found] - $::completionMenuSizey}] command(s) hidden ..."
                }
                $menuName post [winfo rootx $command] [expr {[winfo rooty $command] + [winfo height $command]}]
                $menuName activate 0
                after idle focus $menuName
            }
        }
    }
    # stop focus to next widget
    return -code break
}

main
