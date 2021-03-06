# Program:	auto_rmsd.tcl
# Author:	Bassam Haddad
# 
# Portland State University
# Reichow Lab
#
#	This program calculates the RMSD of a protein selection (e.g. backbone) over a trajectory. There is an auto
#	
#	Procs:
#		align		- aligns the protein backbone
#		inputs: reference molID, selection molID (they can be the same)
#		run		- calculates rmsd for each frame with respect to the reference model.
#		inputs:	output-name (use autormsd)
#		autormsd	- This takes an input .txt file with paths to all of the inputs separated by space or tab. 
#				  This way you can set and forget the rmsd calculations, and ensure they are done the same way.

puts "`align <rmolid> <smolid>`\n"
puts "

proc align {rmolid smolid} {

        set ref_molid $rmolid

        set sel_molid $smolid

        set numframes [molinfo $sel_molid get numframes]

        set ref_frame [atomselect $ref_molid "protein and name CA" frame 0]

        set n 1
 
 	set sys [atomselect $sel_molid all]

        for {set i 0} {$i < $numframes} {incr i} {

                animate goto $i

                set align_frame [atomselect $sel_molid "protein and name CA"]

                set trans_matrix [measure fit $align_frame $ref_frame]

                $sys move $trans_matrix

                if {($n % 100) == 0 } {

                        puts "alignment $n of $numframes"
                }

                incr n

        }

}
proc run {ofile} {

	set initframe 0

	set finaframe [expr [molinfo top get numframes] - 1]

	set output [open $ofile w]

	set rmsd_ref	[atomselect top "protein and name CA" frame 0]

	for {set j $initframe} {$j <= $finaframe} {incr j} {

		animate goto $j

		set rmsd_struc	[atomselect top "protein and name CA"]

		set rmsd_calc	[measure rmsd $rmsd_struc $rmsd_ref]

		puts $output "$j\t$rmsd_calc"

	}

	close	$output

}
proc	 autormsd    {in} {

         set     infile  [open $in r]

         set     inread  [read -nonewline $infile]

         set     inputs  [split $inread "\n"]

         close   $infile

         ## The input file will contain the CryoEM .psf/.pdb, .psf/.dcd, OUT 
         ##                                            0          1       2       
         set     m       0

         foreach line    $inputs {

                 mol new         [lindex $line 0].psf

                 mol addfile     [lindex $line 0].pdb

                 mol new         [lindex $line 1].psf

                 mol addfile     [lindex $line 1].dcd waitfor all

                 align   $m [expr $m + 1]

                 run     [lindex $line 2]

                # mol     delete  $m
                # mol     delete  [expr $m + 1]
		 animate delete	 all

                 set     m       [expr $m + 2]
         }
 }

