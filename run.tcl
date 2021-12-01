#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

# (c) 2017 Alexander Danilov <alexander.a.danilov@gmail.com>

package require Tk
package require Ttk

catch {package require fsdialog}

# minimal number of characters for completion
set minCompletionSize 3

# Maximum size of history file
set historySize 20

# Maximum menu size
set completionMenuSize 30

set term stdout
set command ""


proc main {} {
    ttk::label .l1 -text "Shell command:"
    ttk::entry .command \
        -textvariable command \
        -exportselection false
    button .browse \
        -text Browse \
        -underline 0 \
        -command {browse .command}
    
    ttk::separator .s1 -orient horizontal

    ttk::frame .help
    set font [font configure TkDefaultFont]
    dict set font -size [expr {int([dict get $font -size] * 0.8)}]
    puts $font
    set r 0
    foreach {key desc} {
        ENTER "run command"
        ESCAPE quit
        ↓ "show history"
        "3 characters + Tab" completion
    } {
        label .help.key$r -text $key -font $font
        label .help.desc$r -text "- $desc." -font $font
        grid .help.key$r .help.desc$r -sticky w
        incr r
    }
    grid columnconfigure .help 1 -weight 1
    
    grid .l1 .command .browse -sticky e -padx 5 -pady 2

    grid .s1 - - -sticky ew -padx 5 -pady 5
    grid .help - - -sticky we -padx 5 -pady 5
    grid columnconfigure . .command -weight 2
    #grid anchor .run e

    menu .historyMenu -tearoff 0
    menu .completionMenu -tearoff 0
    readMenu .historyMenu history [list]

    bind . <Escape> quit
    bind .command <Tab> [list completion .completionMenu .command]
    bind .command <Key-Return> run
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
            foreach file [fileutil::findByPattern $path -glob $text*] {
                lappend found [lindex [file split $file] end]
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
