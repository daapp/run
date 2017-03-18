#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

package require Tk

# Put correct path to you wish here.( /usr/bin/wish, on RedHat Linux),
# or may be tixwish, if you don't have Tix or Img as loadable modules

#
# Alternate run command for fvwm95. Copyright(c) by Softweyr, 1997
# All rights reserved. Distributed under GNU Public License
#
# Recommended style:
# Style run  TitleIcon "",NoButton 1, NoButton 4, NoButton 6, WindowListSkip

# Following line can be changed to package require Tix, or commented out
# if you have tix or Img compilied statically.
package require Img

#
# Few global variables which you might change
#

# Maximum size of history file
set history_size 20

# Place, where run.xpm resides
set fvwm_icon_path /usr/X11R6/icons

#list of hosts, which you use to connect via rsh (look into you .rhosts)
set hostlist {rhine mod env amazon}
# do various program require xterm
array set xterm {
grep 1
sed 1
netscape* 0
awk 1
tar 1
mc 1
}
# This procedure creates main window. It could be safely put in main program,
# but...
proc layout {} {
    global hostlist host fvwm_icon_path
    frame .top
    label .top.i ;#-image [image create pixmap -file $fvwm_icon_path/run.xpm]
    label .top.l -text \
        "Type then name of a program or script and Unix will run it for you" \
        -wraplength 300 -justify left -pady 10
    pack .top.i .top.l -side left
    wm title . Run
    wm positionfrom . program
    wm geometry . +50-100
    frame .i
    label .i.l -text Open:
    entry .i.e -width 40 -background white -textvariable command \
        -exportselection false
    bind .i.e <Key-Return> ".b.ok invoke"
    menubutton .i.history -pady 0 -text v -menu .i.history.m -relief \
        raised -bd 2
    menu .i.history.m
    readhistory .i.history.m
    pack .i.l .i.e .i.history -side left
    # This button does almost meaningless thing - chooses redirection of
    # input/output to console or to /dev/null. Probably its meaning should
    # be changed to "Run in xterm"
    checkbutton .r -text "Run without controlling terminal" -variable term\
        -onvalue null -offvalue console
    frame .w
    label .w.l -text "Run on:" -width 15 -anchor e
    eval tk_optionMenu .w.m host localhost $hostlist
    pack .w.l .w.m -side left
    frame .b
    button .b.ok -text Ok -width 8 -command run_it
    button .b.cancel -text Cancel -width 8 -command exit
    button .b.browse -text Browse... -width 8 -command browse
    pack .b.browse .b.cancel .b.ok -side right
    pack .top .i .r .w .b -fill x -expand y
    focus .i.e
}

#
# Pops up standard file selection dialog and inserts selected file into
# command line. Note - not only as command, but as argument as well
#
proc browse {} {
    set name [tk_getOpenFile ]
    if {"$name"==""} return
    if [.i.e selection present] {
        .i.e delete sel.first sel.last
        .i.e insert sel.first $name
    } else {
        .i.e insert insert $name
    }
}

#
# Runs desired command and records it in the history file
#
proc run_it {} {
    global command term host
    if {"$host"=="localhost" } {
        exec /bin/sh -c $command >/dev/$term </dev/$term 2>/dev/$term &
    } else {
        exec rsh $host $command >/dev/$term </dev/$term 2>/dev/$term &
    }
    set f [open ~/.run_history a+]
    puts $f $command
    close $f
    destroy .
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

#
# Now the main program. Set default value for term and create window.
#
set term stdout
layout
