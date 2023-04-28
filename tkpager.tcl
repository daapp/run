#! /bin/sh
# -*- mode: Tcl; -*- \
exec tclsh "$0" ${1+"$@"}

# (c) 2023 Alexander Danilov <alexander.a.danilov@gmail.com>

package require Tk
package require Ttk
package require msgcat

package require inifile

namespace import msgcat::mc msgcat::mcset


array set config {wrap {none char}}
set config(dir) [file join $env(HOME) .config tkpager]
set config(settingsFile) [file join $config(dir) settings]


msgcat::mcset ru "exit" "выйти"
msgcat::mcset ru "Esc - exit" "Esc - выйти"


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
		  -wrap [lindex $config(wrap) 0] \
                  -xscrollcommand [list $f.sx set] \
                  -yscrollcommand [list $f.sy set]]
    if {[info exists config(font,size)]} {
	set font [font actual [$text cget -font]]
	dict set font -size $config(font,size)
	$text configure -font $font
    }
    ttk::scrollbar $f.sx -orient horizontal -command [list $f.text xview]
    ttk::scrollbar $f.sy -orient vertical -command [list $f.text yview]
    rotext $text

    grid $f.text -sticky nsew
    grid $f.sy -row 0 -column 1 -sticky nsew
    grid $f.sx -row 1 -column 0 -sticky ew
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    pack $f -fill both -expand true -side top

    wm title . tkpager

    bind . <Escape> quit
    bind $text <Key-minus> [list changeFontSize %W -1]
    bind $text <Key-equal> [list changeFontSize %W 1]
    bind $text <Key-w> [list changeWrap %W]

    after idle focus $text

    after 1 prepare $text
}


proc rotext {text} {
    foreach t [bind Text] {
	if {![string match *Key* $t] && $t ni {<<Paste>> <<PasteSelection>> <<Clear>> <<Cut>> <<Copy>>}} {
	    bind ROText $t [bind Text $t]
	}
    }
    bind ROText <Control-Key-Tab> [bind Text <Control-Key-Tab>]
    bindtags $text [linsert [lsearch -all -inline -not [bindtags $text] Text] 1 ROText]
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


proc changeFontSize {text val} {
    variable config

    set font [font actual [$text cget -font]]
    dict incr font -size $val
    $text configure -font $font

    set config(font,size) [dict get $font -size]

    return -code break
}


proc changeWrap {text} {
    variable config

    set config(wrap) [concat [lrange $config(wrap) 1 end] [lindex $config(wrap) 0]]
    $text configure -wrap [lindex $config(wrap) 0]

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
