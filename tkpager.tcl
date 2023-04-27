#! /bin/sh
# -*- mode: Tcl; -*- \
exec tclsh "$0" ${1+"$@"}

package require Tk
package require Ttk
package require msgcat

package require inifile

namespace import msgcat::mc msgcat::mcset


array set config {}
set config(dir) [file join $env(HOME) .config tkpager]
set config(settingsFile) [file join $config(dir) settings]


msgcat::mcset ru "exit" "выйти"


ttk::style configure TButton \
    -background lightblue \
    -foreground black \
    -padding {0 7} \
    -width -4
ttk::style map TButton \
    -background [list active lightblue] \
    -foreground [list disabled black]


proc main {args} {
    variable config

    readSettings

    set f [ttk::frame .statusbar]
    ttk::label $f.keys -text [mc "Esc - exit"]
    ttk::button $f.exit -text "Exit" -command quit
    pack $f.keys -side left
    pack $f.exit -side right

    pack $f -fill x -side bottom -pady 5 -padx 5

    set f [ttk::frame .output]
    set text [text $f.text -font TkFixedFont \
                  -xscrollcommand [list $f.sx set] \
                  -yscrollcommand [list $f.sy set]]
    if {[info exists config(font,size)]} {
	set font [font actual [$text cget -font]]
	dict set font -size $config(font,size)
	$text configure -font $font
    }
    ttk::scrollbar $f.sx -orient horizontal -command [list $f.text xview]
    ttk::scrollbar $f.sy -orient vertical -command [list $f.text yview]

    grid $f.text -sticky nsew
    grid $f.sy -row 0 -column 1 -sticky nsew
    grid $f.sx -row 1 -column 0 -sticky ew
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    pack $f -fill both -expand true -side top

    wm title . tkpager

    bind . <Escape> quit
    bind $text <Escape> continue
    bind $text <KeyPress> break
    bind $text <Key-minus> [list changeFontSize %W -1]
    bind $text <Key-equal> [list changeFontSize %W 1]

    after idle focus $text

    after 1 prepare $text
}


proc prepare {text} {
    chan configure stdin -buffering line -blocking 0
    chan event stdin readable [list readData $text]
}


proc readData {text} {
    gets stdin s
    if {[chan eof stdin]} {
        chan close stdin
    }

    set insert [$text index insert]
    $text insert end $s\n
    $text mark set insert $insert
}


proc changeFontSize {w val} {
    variable config

    set font [font actual [$w cget -font]]
    dict incr font -size $val
    $w configure -font $font

    set config(font,size) [dict get $font -size]

    return -code break
}


proc readSettings {} {
    variable config

    file mkdir $config(dir)
    if {[file exists $config(settingsFile)]} {
	set ini [ini::open $config(settingsFile)]
	catch {
	    set fontSize [ini::value $ini font size ""]
	    if {$fontSize ne ""} {
		set config(font,size) $fontSize
	    }
	}
	ini::close $ini
    }
    return
}


proc saveSettings {} {
    variable config
 
    if {[info exists config(font,size)]} {
	set ini [ini::open $config(settingsFile) w]
	ini::set $ini font size $config(font,size)
	ini::commit $ini
	ini::close $ini
    }
}


proc quit {} {
    saveSettings
    exit
}

main {*}$argv
