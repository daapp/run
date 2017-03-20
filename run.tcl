#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

# (c) 2017 Alexander Danilov <alexander.a.danilov@gmail.com>
# tcllib (fileutil package) required to run this application.

package require Tk
package require Ttk

# Maximum size of history file
set history_size 20

#list of hosts, which you use to connect via rsh (look into you .rhosts)
set hostlist {rpi2w}
set term stdout


proc main {} {
    global hostlist host
    ttk::frame .input
    ttk::label .input.l -text "Command: "
    ttk::entry .input.e -textvariable command -exportselection false
    menu .input.menu -tearoff 0
    menu .input.completion_menu -tearoff 0
    readhistory .input.menu
    pack .input.l .input.e -side left -fill y
    pack .input.e -fill x -expand true

    ttk::frame .buttons

    ttk::frame .buttons.w
    ttk::label .buttons.w.l -text "Host: " -anchor w
    eval tk_optionMenu .buttons.w.m host localhost $hostlist
    pack .buttons.w.l .buttons.w.m -side left

    ttk::frame .buttons.s1

    ttk::button .buttons.browse -text Browse... -command browse -underline 0
    grid .buttons.w .buttons.s1 - - .buttons.browse -sticky ew -pady 5 -pady 5
    grid columnconfigure .buttons {1 2 3 4} -uniform a

    pack .input -fill x -expand true -padx 5 -pady 5
    pack .buttons -fill x -padx 5 -pady 0 -expand true

    bind . <Escape> quit
    bind .input.e <Tab> completion
    bind .input.e <Key-Return> run
    bind .input.e <Key-Down> {
        .input.menu post [winfo rootx .input.e] [expr {[winfo rooty .input.e] + [winfo height .input.e]}]
        after idle focus .input.menu
    }
    bind .input.menu <Unmap> {
        after idle {
            focus -force .input.e
            .input.e icursor end
        }
    }
    bind .input.completion_menu <Escape> {
        %W unpost
        after idle {focus -force .input.e}
    }
    bind .input.completion_menu <Unmap> {
        after idle {
            focus -force .input.e
            .input.e icursor end
        }
    }
    bind . <Map> {wm geometry . [winfo reqwidth .]x[winfo reqheight .]}
    bind . <Alt-b> [list .buttons.browse invoke]
    bind . <Alt-h> {
        .buttons.w.m.menu post [winfo rootx .buttons.w.m] [expr {[winfo rooty .buttons.w.m] + [winfo height .buttons.w.m]}]
        after idle focus .buttons.w.m.menu
    }
    bind .buttons.w.m.menu <Unmap> {
        after idle {
            focus -force .input.e
        }
    }

    wm title . Run
    wm positionfrom . program
    wm resizable . 0 0

    tk app Run
    focus -force .input.e
}


proc quit {} {
    destroy .
    exit 0
}

#
# Pops up standard file selection dialog and inserts selected file into
# command line. Note - not only as command, but as argument as well
#
proc browse {} {
    set name [tk_getOpenFile ]
    if {"$name" == ""} return
    if [.input.e selection present] {
        .input.e delete sel.first sel.last
        .input.e insert sel.first $name
    } else {
        .input.e insert insert $name
    }
}

#
# Runs desired command and records it in the history file
#
proc run {} {
    global command term host
    if {"$host"=="localhost" } {
        exec /bin/sh -c $command >/dev/$term </dev/$term 2>/dev/$term &
    } else {
        exec rsh -X $host $command >/dev/$term </dev/$term 2>/dev/$term &
    }
    set f [open ~/.run_history a+]
    puts $f $command
    close $f
    quit
}

#
# Reads history file. If it is too long, deletes first few items and rewrites
# file. Inserts commands from history file in given menu
#
proc readhistory {menu} {
    global history_size
    if [catch {open ~/.run_history} f] {
        $menu add command -label xterm -command "set command xterm"
    } else {
        set list {}
        while {![eof $f]} {
            set entry [gets $f]
            if {![string length $entry]} continue
            set list [linsert $list 0 $entry]
        }
        close $f
        if {[llength $list]>$history_size} {
            set list [lreplace $list $history_size end]
            set f [open ~/.run_history w]
            for {set i [expr $history_size-1]} {$i>=0} {incr i -1} {
                puts $f [lindex $list $i]
            }
            close $f
        }
        foreach entry $list {
            $menu add command -label $entry -command [list set command $entry]
        }
    }
}


proc completion {} {
    set text [.input.e get]
    if {[string length $text] >= 3} {
        .input.completion_menu delete 0 end
        package require fileutil
        set found [list]
        foreach path [split $::env(PATH) :] {
            foreach file [fileutil::findByPattern $path -glob $text*] {
                lappend found [lindex [file split $file] end]
            }
        }
        if {[llength $found] > 0} {
            foreach file [lrange $found 0 4] {
                .input.completion_menu add command -label $file -command [list set command $file]
            }
            if {[llength $found] > 5} {
                .input.completion_menu add command -label "[expr {[llength $found] - 5}] command(s) hidden ..."
            }
            .input.completion_menu post [winfo rootx .input.e] [expr {[winfo rooty .input.e] + [winfo height .input.e]}]
            after idle focus .input.completion_menu
        }
    }
    # stop focus to next widget
    return -code break
}

main
