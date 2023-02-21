#! /bin/sh
# -*- mode: Tcl; -*- \
exec tclsh "$0" ${1+"$@"}

# (c) 2017-2021 Alexander Danilov <alexander.a.danilov@gmail.com>

package require Tk
package require Ttk
package require msgcat
namespace import msgcat::mc msgcat::mcset

catch {package require fsdialog}


set pager tkpager
set dict dict

# minimal number of characters for completion
set minCompletionSize 3

# Maximum size of history file
set historySize 20

# Maximum menu size
set completionMenuSize 30

set term stdout
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
        {⏎ "run command" Alt-d "dictionary"}
        {Esc exit}
        {↓ "show history"}
        {⭾ "completion (after 3 characters)"}
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

    grid .l1 .command .browse -sticky e -padx 5 -pady 2

    grid .s1 - - -sticky ew -padx 5 -pady 5
    grid .help - - -sticky we -padx 5 -pady 5
    grid columnconfigure . .command -weight 2

    menu .historyMenu -tearoff 0
    menu .completionMenu -tearoff 0
    readMenu .historyMenu history [list]

    bind . <Escape> quit
    bind .command <Tab> [list completion .completionMenu .command]
    bind .command <Key-Return> run
    bind .command <Alt-d> runDictionary
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

#
# Runs desired command and records it in the history file
#
proc run {} {
    global command term

    set command [string trim $command]
    if {$command ne ""} {
        exec /bin/sh -c $command >/dev/$term </dev/$term 2>/dev/$term &
        set f [open ~/.run_history a+]
        puts $f $command
        close $f
    }
    quit
}


proc runDictionary {} {
    global command term pager dict

    set word [string trim $command]
    if {$word ne ""} {
        exec $::env(SHELL) -c "$dict '$word' | $pager" &
    }
    quit
}


proc readMenu {menu name defaultValues} {
    global historySize

    if {[catch {open ~/.run_$name} f]} {
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
            set f [open ~/.run_$name w]
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
