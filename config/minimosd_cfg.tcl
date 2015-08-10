
if {[info exists env(HOME)]} {
 set def_settings $env(HOME)/.minimosd_cfg.tcl
 if {[file exists $def_settings]} {
  source $def_settings
 }
}

if {![info exists serial_port]} {set serial_port "/dev/ttyUSB0"}

set eeprom_version 4
set npanels 3
set fw_version "0.5.0"

array set name2addr {
Pitch_en 6 Pitch_x 8 Pitch_y 10
Roll_en 12 Roll_x 14 Roll_y 16
Batt_A_en 18 Batt_A_x 20 Batt_A_y 22
Batt_B_en 24 Batt_B_x 26 Batt_B_y 28
GPSats_en 30 GPSats_x 32 GPSats_y 34
COG_en 36 COG_x 38 COG_y 40
GPS_en 42 GPS_x 44 GPS_y 46
Rose_en 48 Rose_x 50 Rose_y 52
Heading_en 54 Heading_x 56 Heading_y 58
HomeDir_en 66 HomeDir_x 68 HomeDir_y 70
HomeDis_en 72 HomeDis_x 74 HomeDis_y 76
WPDis_en 86 WPDis_x 88  WPDis_y 90  
RSSI_en 92 RSSI_x 94  RSSI_y 96  
Cur_A_en 98 Cur_A_x 100 Cur_A_y 102 
Alt_en 110 Alt_x 112 Alt_y 114
Vel_en 116 Vel_x 118 Vel_y 120
Thr_en 122 Thr_x 124 Thr_y 126
FMod_en 128 FMod_x 130 FMod_y 132
Horizon_en 134 Horizon_x 136 Horizon_y 138
HomeAlt_en 140 HomeAlt_x 142 HomeAlt_y 144
AirSpeed_en 146 AirSpeed_x 148 AirSpeed_y 150
BatteryPercent_en 152 BatteryPercent_x 154 BatteryPercent_y 156
Time_en 158 Time_x 160 Time_y 162
Warn_en 164 Warn_x 166 Warn_y 168
WindSpeed_en 176 WindSpeed_x 178 WindSpeed_y 180
Climb_en 182 Climb_x 184 Climb_y 186
Tune_en 188 Tune_x 190 Tune_y 192
Eff_en 194 Eff_x 196 Eff_y 198
CALLSIGN_en 200 CALLSIGN_x 202 CALLSIGN_y 204
Temp_en 212 Temp_x 214 Temp_y 216
Distance_en 224 Distance_x 226 Distance_y 228
CamPos_en 230 CamPos_x 231 CamPos_y 232

SIGN_MSL_ON 876
SIGN_HA_ON 878
SIGN_GS_ON 880
SIGN_AS_ON 882 
MODEL_TYPE 884 
AUTO_SCREEN_SWITCH 886
BATT_SHOW_PERCENT 888
measure 890
overspeed 892
stall 894
battv 896
RSSI_HIGH 900
RSSI_LOW 902
ch_toggle 906
RSSI_RAW 908
switch_mode 910
PAL_NTSC 912
BATT_WARN 914
RSSI_WARN 916
BRIGHTNESS 918
CALL_SIGN 920
FW_VERSION1 930
FW_VERSION2 932
FW_VERSION3 934
CS_VERSION1 936
CS_VERSION2 937
CS_VERSION3 938
MOTOR_WARN_THR 944
MOTOR_WARN_CURR 945
VOFFSET 946
HOFFSET 947
MAV_BAUD 948
FONT_LOADER_ON 949
EEPROM_OLD_VER 1010
EEPROM_NEW_VER 1014
}

array set var_default {
SIGN_MSL_ON 1
SIGN_HA_ON 1
SIGN_GS_ON 1
SIGN_AS_ON 1
AUTO_SCREEN_SWITCH 4
BATT_SHOW_PERCENT 0
measure 0
overspeed 100
stall 25
battv 101
RSSI_HIGH 255
RSSI_LOW 0
ch_toggle 0
RSSI_RAW 0
PAL_NTSC 1
BATT_WARN 10
RSSI_WARN 10
BRIGHTNESS 0
CALL_SIGN "abcdefgh"
MOTOR_WARN_THR 120
MOTOR_WARN_CURR 50
VOFFSET 0
HOFFSET 0
MAV_BAUD 57
}

set write_ignore_vars {
  EEPROM_OLD_VER EEPROM_NEW_VER  FW_VERSION1 FW_VERSION2 FW_VERSION3
}

set cfg_new_vars {
 VOFFSET HOFFSET MAV_BAUD
 MOTOR_WARN_CURR MOTOR_WARN_THR
 CamPos
}

proc cfg_var_valid {var {panel -1}} {
 if {$::cfg_ver >= 4 && $::cfg_ver != 255} {return 1}
 if {$panel == 2} {return 0}
 if {[lsearch -exact $::cfg_new_vars $var] != -1} {return 0}
 return 1
}

proc cfg_var_cvt {var val} {
 if {$::cfg_ver >= 4 && $::cfg_ver != 255} {return $val}
 if {$var eq "AUTO_SCREEN_SWITCH" && $val == 3} {return 4}
 return $val
}

set ops {
 "write" "read" "mcm2fnt" "fnt2mcm" "writefont" "loadfw"
}

proc usage {code} {
 if {$code == 0} {set f stdout} else {set f stderr}
 set me minimosd_cfg
 puts $f "$me: usage"
 puts $f "\t$me write \[-P <serial_port>] \[-eep <eeprom_file>] \[-cf <config_file>]"
 puts $f "\t$me read \[-P <serial_port>] \[-eep <eeprom_file>] \[-cf <config_file>]"
 puts $f "\t$me mcm2fnt \[-mcm <mcm_file>] \[-fnt <fnt_file>]"
 puts $f "\t$me fnt2mcm \[-mcm <mcm_file>] \[-fnt <fnt_file>]"
 puts $f "\t$me writefont \[-P <serial_port>] \[{-mcm <mcm_file> | -fnt <fnt_file>}]"
 puts $f "\t$me loadfw \[-P <serial_port>] -fw <hex_file>"
 exit $code
}

proc my_error {msg} {
 puts stderr "minimosd_cfg: error: $msg"
 exit 2
}

set op ""
set noclear 0
set mav_config 0

for {set i 0} {$i < [llength $argv]} {incr i} {
 switch [lindex $argv $i] {
  "-eep" {incr i; set fn [lindex $argv $i]}
  "-cf" {incr i; set ofn [lindex $argv $i]}
  "-P" {incr i; set serial_port [lindex $argv $i]}
  "-mcm" {incr i; set mcm_file [lindex $argv $i]}
  "-fnt" {incr i; set fnt_file [lindex $argv $i]}
  "-fw" {incr i; set fwfn [lindex $argv $i]}
  "-noclear" {set noclear 1}
  "-mav" {set mav_config 1}
  "help" {usage 0}
  "write" -
  "read" -
  "mcm2fnt" -
  "fnt2mcm" -
  "writefont" -
  "loadfw" {set op [lindex $argv $i]}
 }
}

if {$op eq ""} {usage 1}

proc bl_connect {} {
 set ofd [open $::serial_port r+]
 fconfigure $ofd -translation binary
 fconfigure $ofd -buffering none
 fconfigure $ofd -timeout 500
 fconfigure $ofd -mode 57600,n,8,1
 fconfigure $ofd -handshake none
 
 fconfigure $ofd -ttycontrol {DTR 1}
 fconfigure $ofd -ttycontrol {DTR 0}
 after 500
 return $ofd
}

proc bl_read_eep {ofd addr n} {
 if {$addr & 1} {
  incr n
  set trim 2
 } else {
  set trim 1
 }
 set addr [expr {$addr/2}]
 puts -nonewline $ofd [binary format "asa" U $addr " "]
 binary scan [read $ofd 2] "H*" resp
 if {$resp ne "1410"} {return {}}
 puts -nonewline $ofd [binary format "aSaa" t $n E " "]
 binary scan [read $ofd [expr {$n+2}]] "cu*" resp
 
 if {[lindex $resp 0] != 0x14} {return {}}
 if {[lindex $resp [expr {$n+1}]] != 0x10} {return {}}
 
 return [lrange $resp $trim end-1]
}

proc bl_write_eep {ofd addr values {verify 0}} {
 if {$addr & 1} {
  set b [bl_read_eep $ofd [expr {$addr-1}] 1]
  if {$b eq ""} {return 0}
  set values [concat $b $values]
 }
 set addr [expr {$addr/2}]
 set n [llength $values]
 puts -nonewline $ofd [binary format "asa" U $addr " "]
 binary scan [read $ofd 2] "H*" resp
 if {$resp ne "1410"} {return 0}
 puts -nonewline $ofd [binary format "aSac*a" d $n E $values " "]
 binary scan [read $ofd 2] "H*" resp
 if {$resp ne "1410"} {return 0}
 if {$verify} {
  set v [bl_read_eep $ofd [expr {$addr*2}] $n]
  foreach i $values j $v {
   if {$i != $j} {puts "verify failed"; return 0}
  }
 }

 return 1
}

proc bl_exit {ofd} {
 puts -nonewline $ofd j
 close $ofd
}

proc panel_var {panel var suffix} {
   set addr [expr {$::name2addr(${var}_${suffix}) + 250*$panel}]
   binary scan $::eep @${addr}cu val
   return $val
}

array set special_get {
 CALL_SIGN read_callsign
 HOFFSET read_vhoffset
 VOFFSET read_vhoffset
}
array set special_set {
 CALL_SIGN write_callsign
 HOFFSET write_vhoffset
 VOFFSET write_vhoffset
}

proc read_callsign {var} {
  set addr $::name2addr($var)
  binary scan $::eep @${addr}a8 val
  return [string trimright $val "\xff\x00"]
}

proc write_callsign {fd var val} {
 set addr $::name2addr($var)
 set val [binary format @7c@0a* 0 $val]
 $::write_var $fd $addr $val
}

proc read_vhoffset {var} {
   set addr $::name2addr($var)
   binary scan $::eep @${addr}cu x
   if {$var eq "HOFFSET"} {return [expr {($x & 0x3f)-32}]}
   return [expr {($x & 0x1f)-16}]
}

proc write_vhoffset {fd var val} {
   set addr $::name2addr($var)
   if {$var eq "HOFFSET"} {
    set val [expr {($val+32) & 0x3f}]
   } else {
    set val [expr {($val+16) & 0x1f}]
   }
   $::write_var $fd $addr [binary format c $val]
}

proc cfg_var {var} {
   if {[info exists ::special_get($var)]} {
    return [$::special_get($var) $var]
   }
   set addr $::name2addr(${var})
   binary scan $::eep @${addr}cu val
   return $val
}

proc dump_panel_cfg {fd var} {
 set sps ""
 for {set i [expr {18-[string length $var]}]} {$i != 0} {incr i -1} {
    append sps " "
 }

 set en "-"
 for {set panel 0} {$panel < $::npanels} {incr panel} {
  if {[panel_var $panel $var en]} {set en "+"}
 }
 puts -nonewline $fd "$en$var$sps"
 for {set panel 0} {$panel < $::npanels} {incr panel} {
   if {![cfg_var_valid $var $panel]} {
    puts -nonewline $fd "-   0   0"
    continue
   }
   set en [panel_var $panel $var en]
   set x [panel_var $panel $var x]
   set y [panel_var $panel $var y]
   if {$en} {set en " +"} else {set en " -"}
   puts -nonewline $fd [format "%s %3d %3d" $en $x $y]
 }
 puts $fd ""
}

proc dump_var {fd var} {
 set sps ""
 for {set i [expr {25-[string length $var]}]} {$i != 0} {incr i -1} {
    append sps " "
 }
 if {[cfg_var_valid $var]} {
  set val [cfg_var_cvt $var [cfg_var $var]]
 } else {
  set val $::var_default($var)
 }
 puts $fd [format "%s%s %s" $var $sps $val]
}

array set plusminus {
 + 1
 - 0
}

proc write_var_file {f addr val} {
 seek $f $addr start
 puts -nonewline $f [binary format "a*" $val]
}

proc write_var_buf {f addr val} {
 set ::eep [binary format "a*@${addr}a*" $::eep $val]
}

proc write_var_bl {f addr val} {
 binary scan $val cu* v
 if {![bl_write_eep $f $addr $v 1]} {
  my_error "write to eeprom @$addr failed"
 }
}

proc write_var_mav {f addr val} {
 if {![osd::write_eeprom $f $addr 1 2000]} {
  my_error "write to eeprom @$addr failed"
 }
}

proc bl_write_eep_all {fd eep} {
  for {set a 0} {$a < 1024} {incr a 128} {
   binary scan $eep @{a}cu128 blkl
   if {![bl_write_eep $bl_fd $a $blkl 1]} {
    my_error "eeprom write failed at @$a"
   }
  }
}

proc set_var {f var val} {
 if {[info exists ::special_set($var)]} {
   $::special_set($var) $f $var $val
   return
 }
 set addr $::name2addr($var)
 #puts "normal var $addr $val"
 $::write_var $f $addr [binary format c $val]
}

proc set_panel_var {f p var suffix val} {
 set addr $::name2addr(${var}_${suffix})
 set addr [expr {$addr + $p*250}]
 #puts "panel var $addr $val [format %02X $val]"
 $::write_var $f $addr [binary format c $val]
}

if {[info exists fn]} {
  set eeprom_access file
} elseif {$mav_config} {
  set eeprom_access mav
} else {
  set eeprom_access bl
}

puts $eeprom_access

proc read_eeprom {} {
 #exec -ignorestderr avrdude -patmega328p -carduino -P $::serial_port -b57600 -D -U "eeprom:r:$fn:r"
 set fd [bl_connect]
 set e [bl_read_eep $fd 0 1024]
 bl_exit $fd
 if {[llength $e] != 1024} {
  my_error "failed to read eeprom"
 }
 return [binary format c* $e]
}

if {$op eq "read"} {
 
 if {$eeprom_access eq "bl"} {
  set eep [read_eeprom]
 } elseif {$eeprom_access eq "mav"} {
  set fd [mav::open_serial $::serial_port]
  set eep [osd::read_eeprom_all $fd 2000]
  close $fd
 } else {
  set f [open $fn r]
  fconfigure $f -translation binary
  set eep [read $f 1024]
  close $f
 }

 set fw_ver [cfg_var FW_VERSION1].[cfg_var FW_VERSION2].[cfg_var FW_VERSION3]
 if {$fw_ver ne $fw_version} {
  puts stderr "minimosd_cfg: warning: firmware version $fw_ver doesn't match this utility ($fw_version)"
  puts stderr "Please, upgrade minimosd_cfg to be sure settings are read correctly."
 }
 set cfg_ver [cfg_var EEPROM_NEW_VER]

 if {[info exists ofn]} {
  set ofd [open $ofn w]
 } else {
  set ofd stdout
 }
 foreach i [lsort [array names name2addr]] {
   if {$name2addr($i) >= 250} continue
   if {![string match "*_en" $i]} continue
   set var [string range $i 0 end-3]
   dump_panel_cfg $ofd $var
  }
  foreach i [lsort [array names name2addr]] {
   if {$name2addr($i) < 250} continue
   dump_var $ofd $i
  }
 if {$ofd ne "stdout"} {close $ofd}
}

if {$op eq "write"} {
 if {[info exists ofn]} {
  set ifd [open $ofn r]
 } else {
  set ifd stdin
 }
 if {$noclear} {
  if {$eeprom_access eq "bl"} {
   set write_var write_var_bl
   set f [bl_connect]
   set close_eep_fd bl_exit
  } elseif {$eeprom_access eq "mav"} {
   set write_var write_var_mav
   set f [mav::open_serial $::serial_port]
   set close_eep_fd mav::close_serial
  } else {
   set write_var write_var_file
   set f [open $fn r+]
   fconfigure $f -translation binary
   set close_eep_fd close
  }
 } else {
  set write_var write_var_buf
  set eep [binary format @1023c 0]
  set f {}
 }
 while {![eof $ifd]} {
  set s [gets $ifd]
  if {[string index [lindex $s 0] 0] eq "#"} continue
  if {[llength $s] == 0} continue
  if {[llength $s] == 2} {
   if {[lsearch -exact $write_ignore_vars [lindex $s 0]] != -1} continue
   set var [lindex $s 0]
   set_var $f $var  [lindex $s 1]
   set v_set($var) 1
   continue
  }
  if {[llength $s] >= 4} {
   set np [expr {([llength $s]-1)/3}]
   if {$np > $npanels} {set np $npanels}
   set var [string range [lindex $s 0] 1 end]
   set off 1
   for {set p 0} {$p < $np} {incr p} {
    set_panel_var $f $p $var en $plusminus([lindex $s $off]) 
    incr off
    set_panel_var $f $p $var x [lindex $s $off] 
    incr off
    set_panel_var $f $p $var y [lindex $s $off]
    incr off
    set pv_set(${var}_en) 1
   }
   for {} {$p < $npanels} {incr p} {
    set_panel_var $f $p $var en 0
   }
   continue
  }
  my_error "unexpected config string: $s"
 }
 if {$ifd ne "stdin"} {close $ifd}
 if {!$noclear} {
   # set defaults
   foreach i [array names name2addr] {
    if {[info exists v_set($i)] || [info exists pv_set($i)]} continue
    if {[string match *_en $i]} {
     # disable all panel displays by default
     set var [string range $i 0 end-3]
     for {set p 0} {$p < $npanels} {incr p} {
      set_panel_var $f $p $var en 0
     }
    } elseif {[info exists var_default($i)]} {
     set_var $f $i $var_default($i)
    }
   }
   set_var $f EEPROM_NEW_VER $eeprom_version
   set_var $f EEPROM_OLD_VER 76
   set fw_ver [string map {. " "} $fw_version]
   set_var $f FW_VERSION1 [lindex $fw_ver 0]
   set_var $f FW_VERSION2 [lindex $fw_ver 1]
   set_var $f FW_VERSION3 [lindex $fw_ver 2]
   if {$eeprom_access eq "bl"} {
    set bl_fd [bl_connect]
    bl_write_eep_all $bl_fd $eep
    bl_exit $bl_fd
   } elseif {$eeprom_access eq "file"} {
    set f [open $fn w]
    fconfigure $f -translation binary
    puts -nonewline $f $eep
    close $f
   } else {
    set f [mav::open_serial $::serial_port]
    osd::write_eeprom_all $f $eep 1 2000
    mav::close_serial $f
   }
 } else {
   $close_eep_fd $f
 }
}

proc read_bit {fd} {
 while {1} {
  set b [read $fd 1]
  if {$b eq "0"} {return $b}
  if {$b eq "1"} {return $b}
 }
}
if {$op eq "mcm2fnt"} {
 array set bit2char {
  0,0 *
  1,0 O
  0,1 _
  1,1 _
 }
 if {[info exists fnt_file]} {
  set ofd [open $fnt_file w]
 } else {
  set ofd stdout
 }
 if {[info exists mcm_file]} {
  set ifd [open $mcm_file r]
 } else {
  set ifd stdin
 }
 for {set char_cnt 0} {$char_cnt < 256} {incr char_cnt} {
  puts $ofd [format 0x%02x $char_cnt]
  for {set y_cnt 0} {$y_cnt < 18} {incr y_cnt} {
   for {set x_cnt 0} {$x_cnt < 12} {incr x_cnt} {
    set b1 [read_bit $ifd]
    set b2 [read_bit $ifd]
    puts -nonewline $ofd $bit2char($b1,$b2)
   }
   puts $ofd ""
  }
  for {set i 0} {$i < 80} {incr i} {read_bit $ifd}
 }
 if {$ofd ne "stdout"} {close $ofd}
 if {$ifd ne "stdin"} {close $ifd}
}

array set char2bit {
  * "00"
  O "10"
  _ "01"
}

set linepos 0
proc read_fnt_px {fd} {
 while {1} {
  set b [read $fd 1]
  if {[info exists ::char2bit($b)]} {
   incr ::linepos
   if {$::linepos == 12} {
    gets $fd
    set ::linepos 0
   }
   return $::char2bit($b)
  }
  if {$b eq "\r" || $b eq "\n"} {
   my_error "unexpected end of string"
  }
  if {[eof $fd]} {
   my_error "premature end of file"
  }
 }
}

proc fnt2mcm {ifd} {
 set ch {}
 for {set y_cnt 0} {$y_cnt < 54} {incr y_cnt} {
  set b ""
  for {set x_cnt 0} {$x_cnt < 4} {incr x_cnt} {
   append b [read_fnt_px $ifd]
  }
  lappend ch $b
 }
 for {set i 0} {$i < 10} {incr i} {
   lappend ch "01010101"
 }
 return $ch
}

proc read_fnt {ifd} {
 array set fnt {}
 while {[array size fnt] != 256} {
  set cn [expr {[gets $ifd]}]
  if {[eof $ifd]} {
   set g {}
   for {set i 0} {$i < 256} {incr i} {
    if {![info exists fnt($i)]} {
     lappend g $i
    }
   }
   my_error "premature end of file: more glyphs expected: $g"
  }
  set ch [fnt2mcm $ifd]
  if {[info exists fnt($cn)]} {puts stderr "warning: duplicate glyph $cn"}
  set fnt($cn) $ch
 }
 set l {}
 for {set i 0} {$i < 256} {incr i} {
  lappend l $fnt($i)
 }
 return $l
}

if {$op eq "fnt2mcm"} {
 if {[info exists fnt_file]} {
  set ifd [open $fnt_file r]
 } else {
  set ifd stdin
 }
 if {[info exists mcm_file]} {
  set ofd [open $mcm_file w]
 } else {
  set ofd stdout
 }
 set l [read_fnt $ifd]
 fconfigure $ofd -translation crlf
 puts -nonewline $ofd "MAX7456"
 for {set char_cnt 0} {$char_cnt < 256} {incr char_cnt} {
  set ch [lindex $l $char_cnt]
  for {set y_cnt 0} {$y_cnt < 64} {incr y_cnt} {
   puts $ofd ""
   puts -nonewline $ofd [lindex $ch $y_cnt]
  }
 }
 if {$ofd ne "stdout"} {close $ofd}
 if {$ifd ne "stdin"} {close $ifd}
}

proc get_font_loader_resp {fd buf resp} {
 upvar $buf mybuf
 set b [read $fd 1]
 if {$b eq ""} {return "timeout"}
 append mybuf $b
 if {[string compare -length [string length $mybuf] $mybuf $resp] != 0} {
   my_error "unexpected response from font loader"
 }
 if {$mybuf eq $resp} {return "ok"}
 return "nextch"
}

if {$op eq "writefont"} {
 if {[info exists fnt_file]} {
  set ifd [open $fnt_file r]
  set font_format "fnt"
  set fnt [read_fnt $ifd]
 } elseif {[info exists mcm_file]} {
  set ifd [open $mcm_file r]
  set header [gets $ifd]
  if {$header ne "MAX7456"} {
   my_error "$mcm_file doesn't look like mcm"
  }
  set font_format "mcm"
 } else {
  set ifd stdin
  set font_format "fnt"
 }
 set ofd [bl_connect]
 set fl_en [bl_read_eep $ofd $name2addr(FONT_LOADER_ON) 1]
 if {$fl_en eq ""} {
  my_error "no response from bootloader"
 }
 set mav_baud [bl_read_eep $ofd $name2addr(MAV_BAUD) 1]
 if {$fl_en eq ""} {
  my_error "no response from bootloader"
 }
 if {!$fl_en} {
  puts -nonewline "Enabling font loader: "
  flush stdout
  if {![bl_write_eep $ofd $name2addr(FONT_LOADER_ON) 1]} {
   my_error "write to eeprom failed"
  }
  puts done.
 }
 bl_exit $ofd
 if {$mav_baud == 115} {set mav_baud 115200} else {set mav_baud 57600}
 set ofd [open $serial_port r+]
 fconfigure $ofd -translation crlf
 fconfigure $ofd -buffering line
 fconfigure $ofd -timeout 400
 fconfigure $ofd -mode $mav_baud,n,8,1
 fconfigure $ofd -handshake none
 set resp ""
 set timeou 25
 while {1} {
  puts $ofd ""
  puts $ofd ""
  puts $ofd ""
  set r [get_font_loader_resp $ofd resp "Ready for Font\n"]
  if {$r eq "ok"} break
  if {$r eq "nextch"} continue
  incr timeou -1
  if {!$timeou} {
    my_error "timeout waiting for responce from font loader"
  }
 }
 puts -nonewline "Font loader is ready, writing chars: "
 flush stdout
 for {set char 0} {$char < 256} {incr char} {
  if {$font_format eq "mcm"} {
   for {set byte 0} {$byte < 64} {incr byte} {
    puts $ofd [gets $ifd]
   }
  } else {
   set ch [lindex $fnt $char]
   for {set byte 0} {$byte < 64} {incr byte} {
    puts $ofd [lindex $ch $byte]
   }
  }
  set resp ""
  set timeo 10
  while {1} {
   set r [get_font_loader_resp $ofd resp "Char Done\n"]
   if {$r eq "ok"} break
   if {$r eq "nextch"} continue
   incr timeo -1
   if {!$timeo} {
    my_error "timeout waiting for responce after char $char"
   }
  }
  if {$char % 10 == 0} {puts -nonewline .; flush stdout}
 }
 puts "done."
 close $ofd
 if {$ifd ne "stdin"} {close $ifd}
 if {!$fl_en} {
  puts -nonewline "Disabling font loader: "
  flush stdout
  set ofd [bl_connect]
  bl_write_eep $ofd $name2addr(FONT_LOADER_ON) 0
  bl_exit $ofd
  puts done.
 }
}

if {$op eq "loadfw"} {
  exec -ignorestderr avrdude -patmega328p -carduino -P $serial_port -b57600 -D -U "flash:w:$fwfn:i"
}