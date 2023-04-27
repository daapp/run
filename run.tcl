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
set config(historyFile) [file join $config(dir) history]
set config(settingsFile) [file join $config(dir) settings]
array set config {
    pager tkpager
    dict dict
    term stdout
    minCompletionSize 3
    historySize 20
    completionMenuSize 30
    saveSettings {pager minCompletionSize historySize}
}

set config(userCommandFile) [file join $config(dir) user_commands]
set config(userCommands)    [list [list Alt-d "dictionary" "$config(dict) '%s'"]]

# minimal number of characters for completion
# Maximum size of history file
# Maximum menu size

set command ""


msgcat::mcset ru "run command" "выполнить команду"
msgcat::mcset ru "dictionary" "словарь"
msgcat::mcset ru "show history" "показать историю"
msgcat::mcset ru "completion (after %d characters)" "дополнение (после %d знаков)"
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
    readSettings

    set f [frame .input]
    ttk::label $f.l1 -text [mc "Shell command"]:
    set wCommand [ttk::entry $f.command \
                        -textvariable command \
                        -exportselection false]
    button $f.browse \
        -text [mc 🗀] \
        -command [list browse $wCommand]
    button $f.settings -text [mc ⚙] -command [list showSettings]

    ttk::separator .s1 -orient horizontal

    ttk::frame .help
    set font [font configure TkDefaultFont]
    dict set font -size [expr {int([dict get $font -size] * 0.8)}]
    set r 0
    foreach row [list \
		     [list ⏎ [mc "run command"] Esc [mc exit]] \
		     [list ↓ [mc "show history"] ⭾ [mc "completion (after %d characters)" $config(minCompletionSize)]]] {
        set ws [list]
        set c1 0
        set c2 1
        foreach {key desc} $row {
            ttk::button .help.key$r$c1 -text $key -state disabled;# -font $font
            label .help.desc$r$c2 -text " - $desc." ;#-font $font
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
            bind $wCommand <$binding> [list runUserCommand [string map {% %%} $userCommand]]
        }
        if {[llength $ws] != 0} {
            lappend table $ws
        }
        foreach row $table {
            grid {*}$row -sticky w -pady 3
        }
    }

    pack $f.l1 -side left
    pack $f.command -side left -fill x -expand true
    pack $f.browse $f.settings -side left -padx 5 -pady 2

    grid $f -sticky ew -padx 5 -pady 5
    grid .s1 - - -sticky ew -padx 5 -pady 5
    grid .help - - -sticky we -padx 5 -pady 5
    grid columnconfigure . $f -weight 2

    menu .historyMenu -tearoff 0
    menu .completionMenu -tearoff 0
    readMenu .historyMenu

    bind . <Escape> quit
    bind $wCommand <Tab> [list completion .completionMenu $wCommand]
    bind $wCommand <Key-Return> {run history}
    bind $wCommand <Key-Down> {
        if {$command ne ""} {
            .completionMenu activate 0
            after idle focus .completionMenu
        } else {
            .historyMenu post [winfo rootx $wCommand] [expr {[winfo rooty $wCommand] + [winfo height $wCommand]}]
            after idle focus .historyMenu
        }
    }
    bind .historyMenu <Unmap> {
        after idle {
            focus -force $wCommand
            $wCommand icursor end
        }
    }
    bind .completionMenu <Escape> {
        %W unpost
        after idle {focus -force $wCommand}
    }
    bind .completionMenu <Unmap> {
        after idle {
            focus -force $wCommand
            $wCommand icursor end
        }
    }
    bind . <Map> {wm geometry . [winfo reqwidth .]x[winfo reqheight .]}
    bind . <Alt-b> {.browse invoke}

    wm title . Run
    wm positionfrom . program
    wm resizable . 0 0

    tk app Run
    focus -force $wCommand
}


proc saveSettings {} {
    variable config

    set f [open $config(settingsFile) w]
    foreach {k} $config(saveSettings) {
        chan puts $f "$k $config($k)"
    }
    chan close $f
}


proc quit {} {

    destroy .
    exit 0
}


proc readSettings {} {
    variable config

    if {![catch {set f [open $config(settingsFile) r]}]} {
        foreach k $config(saveSettings) {
            set s [chan gets $f]
            set config([lindex $s 0]) [lrange $s 1 end]
        }
        chan close $f
    }
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
    if {![catch {set f [open $fileName r]} e]} {
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
        set f [open $config(historyFile) a+]
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


proc readMenu {menu} {
    variable config

    if {![catch {open $config(historyFile) r} f]} {
        set list {}
        while {![eof $f]} {
            set entry [gets $f]
            if {![string length $entry]} continue
            set list [linsert $list 0 $entry]
        }
        close $f
        if {[llength $list] > $config(historySize)} {
            set list [lreplace $list $config(historySize) end]
            set f [open $config(historyFile) w]
            foreach h [lrange $list 0 $config(historySize)] {
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
    variable config

    set text [$command get]
    if {[string length $text] >= $config(minCompletionSize)} {
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
                foreach file [lrange $found 0 [expr {$config(completionMenuSize) - 1}]] {
                    $menuName add command -label $file -command [list set command $file]
                }
                if {[llength $found] > $config(completionMenuSize)} {
                    $menuName add command -label "[expr {[llength $found] - $config(completionMenuSize)}] command(s) hidden ..."
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


proc centerWindow {w} {
    wm withdraw $w
    update idletasks
    set x [expr {[winfo screenwidth $w]/2 -
                 [winfo reqwidth $w]/2 -
                 [winfo vrootx [winfo parent $w]]
             }]
    set y [expr {[winfo screenheight $w]/2 -
                 [winfo reqheight $w]/2 -
                 [winfo vrooty [winfo parent $w]]
             }]
    wm geom $w +$x+$y
    wm deiconify $w
}


proc showSettings {} {
    set w [toplevel .settings]

    set f [frame $w.data]
    ttk::label $f.lpager -text [mc "Pager"]:
    ttk::entry $f.pager -textvariable config(pager)
    ttk::label $f.lMinCompletionSize -text [mc "Minimal characters for completion"]:
    ttk::spinbox $f.minCompletionSize -from 3 -to 10 -textvariable config(minCompletionSize)
    ttk::label $f.lHistorySize -text [mc "History size"]:
    ttk::spinbox $f.historySize -from 3 -to 40 -textvariable config(historySize)
    grid $f.lpager $f.pager -sticky ew -padx 5 -pady 5
    grid $f.lMinCompletionSize $f.minCompletionSize -sticky ew -padx 5 -pady 5
    grid $f.lHistorySize $f.historySize -sticky ew -padx 5 -pady 5

    frame $w.sep1 -height 2 -relief ridge -bd 1

    frame $w.buttons
    button $w.buttons.save -text [mc Save] -command saveSettings
    button $w.buttons.close -text [mc Close] -command [list destroy $w]
    pack $w.buttons.close $w.buttons.save -side right -padx 5

    pack $w.data -side top -fill both -expand true -padx 5 -pady 5
    pack $w.sep1 -side top -fill x -padx 5 -pady 5
    pack $w.buttons -side bottom -fill x -pady 5

    bind $w <Escape> [list destroy $w]

    wm title $w [mc "Settings"]
    wm resizable $w 0 0
    wm minsize $w

    centerWindow $w
}


main
