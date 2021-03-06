# Program:	Lip-Analysis-Tools.tcl
# Author:	Bassam Haddad
# 
# Portland State University
# Reichow Lab
#
# 	This program is an essential component of LipNetwork.tcl, which analyzes the arrangement of lipids around the extra-
#	cellular leaflet of Cx46/50 gap junctions. Lip-Analysis-Tools.tcl was originally a set of vmd tools to look at lipids
#	around a gap junction, and now is essential for LipNetwork to properly function.
#
#	This program does not need to be sourced individually, as it is sourced by LipNetwork.tcl.

source	~/Scripts/TCL/Tcl-Scripts/calc_op_module.tcl
source	~/Scripts/TCL/Tcl-Scripts/calc_op.tcl

proc	Title	{{v ""}} {

	if {$v == "-v"} {
		puts		""
		puts		"Proc Lip-align:	Takes the users selection of any lipids, and aligns them together to a reference lipid.\n"
		puts		"			Press '1' and select the lipids that you want aligned in the VMD GUI...\n"
		puts		"			To run '$ Lip-align <MOLID>'\n"
		puts		"Proc align:		aligns trajectory relative to the protein...i.e. aligns the protein to itself or a separate protein.\n"
		puts		"			Select the molid for the reference and the selection. Uses the first frame from the ref. molid as the reference for the whole system.\n"
		puts		"			To run '$ align'\n"
		puts		"Proc Prot-align:	Takes all of the annular lipids around the protein, and aligns them to a single protein chain.\n"
		puts		"			To run '$ Prot-align <MOLID> <LOGFILE-NAME> <CHAIN>'\n"
		puts            "Proc LipNetwork:	Using the centers file, containing the (x,y) coordinates of the annular\n"
                puts            "			lipid densities (from MD or CryoEM) and calculates the interconnectivity\n" 
                puts            "			of the lipid tails within the densities. This script creates a 'transition\n"
                puts            "			matrix' that shows when any two lipid densities are occupied by a single\n"
                puts            "			lipid. The default minimum IsoLow is 0, meaning the density does not matter\n" 
                puts            "			and thus assumed that a tail is always assigned to a lipid density 'region'.\n"
                puts            "			In order for this program to work, the volume file (.mrc or .dx) must be\n"
                puts            "			loaded into the top molecule (the one containing your .dcd. Furthermore, \n"
                puts            "			you need to run 'align' and 'Prot-align' to ensure the protein/lipids are \n"
                puts            "			at there best-fit to each other.\n"
		puts            "			To run '$ LipNetwork <CENTER FILE> <OUTFILE> <CARBON-THRESHOLD> <ISO-THRESHOLD (default: none)> <DIFSEL (default: false)>'\n"

	} else {

		puts		""
		puts            "			To run '$ Lip-align <MOLID>'\n"
		puts            "			To run '$ align'\n"
		puts            " 			To run '$ Prot-align <MOLID> <LOGFILE-NAME> <CHAIN>'\n"
		puts            " 			To run '$ LipNetwork <CENTER FILE> <OUTFILE> <CARBON-THRESHOLD> <ISO-THRESHOLD (def: none)> <DIFSEL (def: false)>'\n"
		puts		"			To run '$ lipid_animator <LipList> <molid>'\n"
		puts		"			To run '$ PerLipidOP <outname>'\n"
	}
}


# Aligns lipids together to show how similar/different they are. Demonstrates the range of motion,
# but does not preserve information on their contact with the protein.

proc	Lip-align	{MOLID} {

	set	AtomList	[label list Atoms]

	set	NumFrames	[molinfo $MOLID get numframes]

	set	ref_lip		[atomselect $MOLID "same residue as index [lindex $AtomList {0 0 1}]"]

	set	n		0

	foreach	line	$AtomList {

		set	Index		[lindex $line {0 1}]
		
		set	align_lip	[atomselect top "same residue as (index $Index)"]

		for {set i 0} {$i < $NumFrames} {incr i} {

			animate goto $i

			set trans_matrix	[measure fit $align_lip $ref_lip]

			$align_lip move $trans_matrix

		}

	}
	Title
}


proc align {} {

	puts -nonewline " Provide molID for reference."
	flush stdout

	set ref_molid [gets stdin]

	puts -nonewline " Provide molID for selection."
	flush stdout

	set sel_molid [gets stdin]

	set numframes [molinfo $sel_molid get numframes]

	set ref_frame [atomselect $ref_molid "protein and name CA" frame 0]

	set n 1

	set sys [atomselect $sel_molid all]

	set frame_percent [expr {round($numframes / 30)}]

	for {set i 0} {$i < $numframes} {incr i} {

                animate goto $i

                set align_frame [atomselect $sel_molid "protein and name CA"]

                set trans_matrix [measure fit $align_frame $ref_frame]

                $sys move $trans_matrix

		if {($i % $frame_percent) == 0 } {

			puts -nonewline "*"
			flush stdout
		}

        }

        puts  "\nAlignments complete, ready for RMSD calculations"
	Title
}



proc	Prot-align	{MOLID logfile {RefChain A}} {

	set	log	[open $logfile w]
	puts	$log	"RESID\t\tSEGID\t\tLip-Head RMSF\t\tLip-Tail RMSF\t\tLip-Tot RMSF\n"

	# Select the protein chain (connexin) that will be the reference for transformation

	set ProtChainList	[lsort -unique [[atomselect $MOLID protein] get chain]]	

	set NumFrames		[molinfo $MOLID get numframes]

	set ref_prot		[atomselect $MOLID "protein and chain $RefChain frame 0"]

	foreach chain $ProtChainList {

		set	Phos_List	""

		set	align_prot	[atomselect $MOLID "protein and chain $chain"]

		for {set n 0} {$n < $NumFrames} {incr n} {
			
			animate goto $n

			set	Prot_Lip	[atomselect $MOLID "resname DMPC and same residue as within 10 of (protein and (resid 84 215) and chain $chain)"]

			$Prot_Lip		set beta 1

			set	hold		[[atomselect $MOLID "name P and beta = 1"] get index]

			set	Phos_List	[concat	[lindex $Phos_List] [lindex $hold]]
		
			$Prot_Lip		set beta 0

			unset	hold
		}

		set Phos_Ind	[lsort -unique $Phos_List]

		set Lip_Sel	[atomselect $MOLID "same residue as index [lindex $Phos_Ind]"]

		unset Phos_List

		for {set i 0} {$i < $NumFrames} {incr i} {

			animate goto $i

			set trans_matrix	[measure fit $align_prot $ref_prot]

			$Lip_Sel move $trans_matrix
		}

		foreach phos $Phos_Ind {

			set	IND	[atomselect $MOLID "index $phos"]

			set	ResID	[$IND get resid]
			set	SegID	[$IND get segid]

			set	LipTot	[atomselect $MOLID "resid $ResID and segid $SegID"]
			set	LipTail	[atomselect $MOLID "resid $ResID and segid $SegID and (name C22 to C29 C210 to C214 C32 to C39 C310 to C314)"]
			set	LipHead	[atomselect $MOLID "resid $ResID and segid $SegID and (name O21 O22 O31 O32 O11 to O14 C1 C2 C21 C3 C31 C11 to C15 P N)"]

			set	Headr	[measure rmsf $LipHead]
			set	Tailr	[measure rmsf $LipTail]
			set	Totar	[measure rmsf $LipTot]
			
			set	headhold	0
			set	tailhold	0
			set	totalhold	0

			foreach	head $Headr {set headhold	[expr $headhold + $head]}
			foreach tail $Tailr {set tailhold	[expr $tailhold + $tail]}
			foreach total $Totar {set totalhold	[expr $totalhold + $total]}
	
			set	HeadrA		[expr $headhold / [llength $Headr]]
			set	TailrA		[expr $tailhold / [llength $Tailr]]
			set	TotarA		[expr $totalhold / [llength $Totar]]

		puts	$log	"$ResID\t\t$SegID\t\t$HeadrA\t\t$TailrA\t\t$TotarA\n"
		}

		puts -nonewline "*"

	}
	close	$log

	puts "*"

	Title
}

proc	PerLipidOP {outname} {

	set	lipids	[atomselect top "lipids and name P"]

	set	num_lip	[$lipids num]

	set	ResList	[$lipids get resid]

	set	SegList	[$lipids get segid]

	set	k	1

	set	prot	[atomselect top protein]
	set	prot_x	[lindex	[measure center $prot]	0]
	set	prot_y	[lindex [measure center $prot]	1]

	foreach segid $SegList resid $ResList {
	
		set	lipid	[atomselect top "resid $resid and segid $segid"]
		set	lip_x	[lindex [measure center $lipid]	0]
		set	lip_y	[lindex [measure center $lipid] 1]

		set	radius	[expr {sqrt(pow(($lip_x - $prot_x),2) + pow(($lip_y - $prot_y),2))}]

		orderparam-c2	arr2	"resid $resid and segid $segid"
		
		set		listc2	""

		foreach {carbon	parval}	[array get arr2] {
			
			lappend	listc2	"$carbon $parval"
		}

		orderparam-c3	arr3	"resid $resid and segid $segid"

		set		listc3	""

		foreach {carbon parval} [array get arr3] {

			lappend	listc3	"$carbon $parval"
		}

		set	sum2	0
		set	sum3	0

		for {set i 0} {$i <= 12} {incr i} {

# Only averaging carbons 3 to 11 (appear in 'flat' region of figure), thus only looking at contributions of indices i -> 9

			if {$i >= 1 && $i <= 9} {

				set	sum2	[expr [lindex $listc2 $i 1] + $sum2]
				set	sum3	[expr [lindex $listc3 $i 1] + $sum3]
			}

			if {$i == 12} {
			
				set	avg2		[expr $sum2 / 9]
				set	avg3		[expr $sum3 / 9]

				dict	set	OParam	$k	RESID	$resid
				dict	set	OParam	$k	SEGID	$segid
				dict	set	OParam	$k	C2OP	$listc2
				dict	set	OParam	$k	C2Avg	$avg2
				dict	set	OParam	$k	C3OP	$listc3
				dict	set	OParam	$k	C3Avg	$avg3
				dict	set	OParam	$k	Radius	$radius
				incr	k
				puts "$k"
			}
		}
	}

	animate	goto	0

	set	all	[atomselect top all]

	$all	set	beta	0

	set	out	[open $outname w]

	for {set i 1} {$i < $k} {incr i} {

		set	AcylC2	[atomselect top "resid [dict get $OParam $i RESID] and segid [dict get $OParam $i SEGID] and (name C22 to C29 C210 to C214)"]

		set	AcylC3	[atomselect top "resid [dict get $OParam $i RESID] and segid [dict get $OParam $i SEGID] and (name C32 to C39 C310 to C314)"]
		
		$AcylC2	set	beta	[dict get $OParam $i C2Avg]

		$AcylC3 set	beta	[dict get $OParam $i C3Avg]

		puts	$out	"$resid\t$segid\t$avg2\t$avg3\t$radius\n"
	}

	$all	writepdb	$outname.pdb

	$all	writepsf	$outname.psf

	close	$out
}

proc	SymLipOP {outname dr dmax zmaxU zminL} {

#	dmax must be a multiple of dr

	set num_shell	[expr $dmax / $dr] 

	set c		0

	# isolate shells of lipids that are dr angstroms thick (only affecting the beta-value of the phosphates)

	for {set i $num_shell} {$i >= 1} {set i [expr $i - 1]} {

		set	shell_upper	[atomselect top "lipids and name P and (z > $zmaxU or z < $zminL) and within [expr $dmax - [expr $c * $dr]] of protein"] 
		set	shell_lower	[atomselect top "lipids and name P and (z < $zmaxU and z > $zminL) and within [expr $dmax - [expr $c * $dr]] of protein"]

		$shell_upper set	beta	$i
		$shell_lower set	beta	$i

		incr	c
	}

	# Select the lipids for the upper and lower leaflets

	for {set i $num_shell} {$i >= 1} {set i [expr $i - 1]} {

		set	shell_upper_($i)	[atomselect top "lipids and name P and (z > $zmaxU or z < $zminL) and beta = $i"]
		set	shell_lower_($i)	[atomselect top "lipids and name P and (z < $zmaxU and z > $zminL) and beta = $i"]

		set	upper_resid_($i)	[$shell_upper_($i) get resid]
		set	upper_segid_($i)	[$shell_upper_($i) get segid]

		set	lower_resid_($i)	[$shell_lower_($i) get resid]
		set	lower_segid_($i)	[$shell_lower_($i) get segid]
	}

	# Calculate the average Scd Order Parameter for each shell/leaflet

	for {set i $num_shell} {$i >= 1} {set i [expr $i - 1]} {

		set	sumU	0
		set	sumL	0
		set	U	0
		set	L	0

		# Sum all of the beta fields from each lipid-tail carbon within a shell/leaflet, and keep track of the number of carbons being summed

		foreach resid $upper_resid_($i) segid $upper_segid_($i) {

			set	tail_c	[atomselect top "resid $resid and segid $segid and (name C22 to C29 C210 C211 C32 to C39 C310 C311)"]
			set	CD_list	[$tail_c get beta]

			foreach val $CD_list { 
				
				set	sumU	[expr $sumU + $val]
				
				incr	U
			}

			unset	tail_c CD_list
		}

		if {$U != 0}	{set	avgU_($i)	[expr $sumU / $U]} 
		 
		foreach resid $lower_resid_($i) segid $lower_segid_($i) {

			set	tail_c	[atomselect top "resid $resid and segid $segid and (name C22 to C29 C210 C211 C32 to C39 C310 C311)"]
			set     CD_list [$tail_c get beta]

			foreach val $CD_list {

				set     sumL    [expr $sumL + $val]

				incr	L
			}

			unset	tail_c CD_list
		}

		if {$L != 0}	{set	avgL_($i)	[expr $sumL / $L]}

		# Colour the lipids (whole) by the average beta-values of the lipid-tails

		foreach residU $upper_resid_($i) segidU $upper_segid_($i) {

		       #set	upper	[atomselect top "resid $residU and segid $segidU and ((name C22 to C29 C210 to C214) or (name C32 to C39 C310 to C314))"]
			set	upper	[atomselect top "resid $residU and segid $segidU"]

			$upper	set	beta	$avgU_($i)
		}

		foreach residL $lower_resid_($i) segidL $lower_segid_($i) {

		       #set	lower	[atomselect top "resid $residL and segid $segidL and ((name C22 to C29 C210 to C214) or (name C32 to C39 C310 to C314))"]
			set	lower	[atomselect top "resid $residL and segid $segidL"]	

			$lower	set	beta	$avgL_($i)
		}
	}

	set	all	[atomselect top all]

	$all	writepsf	$outname.psf
	$all	writepdb	$outname.pdb
}

proc	RadLipOP {outname dr dmax zmaxU zminL} {

	#This splits the surrounding lipids into shells of thickness dr, out to a distance dmax. zmaxU/2 are bounds for where the inner and outer leaflets
	# are located. 

	set	num_shell	[expr $dmax / $dr]

	set	c	0
	# Starting with the outermost shell allows us to assign beta values within each shell due to the way atomselections work...if we start from 
	# shell-1 then we will constantly re-write the beta-values of the shells near the center.
	
	for {set i $num_shell} {$i >= 1} {set i [expr $i - 1]} {

		set	shell_upper($i)	[atomselect top "lipids and name P and (z > $zmaxU or z < $zminL) and within [expr $dmax - [expr $c * $dr]] of protein"]

		set	shell_lower($i) [atomselect top "lipids and name P and (z < $zmaxU and z > $zminL) and within [expr $dmax - [expr $c * $dr]] of protein"]

		incr	c
	}

	for {set i $num_shell} {$i >= 1} {set i [expr $i - 1]} {

		$shell_upper($i) set beta $i
		$shell_lower($i) set beta [expr $i + 10]
	}

	for {set i 0} {$i < 8} {incr i} {

		set	a	[expr $i * $dr]
		set	b	[expr $a + $dr]

#		set	($a)to($b)_upper	"all and same residue as beta = [expr $i + 1]"
#		set	($a)to($b)_lower	"all and same residue as beta = [expr $i + 11]"

		puts	"Starting $a -> $b upper sn2"
		
		orderparam-c2m arr1 "all and same residue as beta = [expr $i + 1]" ($a)to($b)_upper_sn2

		puts	"Starting $a -> $b upper sn3"

		orderparam-c3m arr2 "all and same residue as beta = [expr $i + 1]" ($a)to($b)_upper_sn3

		puts	"Starting $a -> $b lower sn2"

		orderparam-c2m arr3 "all and same residue as beta = [expr $i + 11]" ($a)to($b)_lower_sn2

		puts	"Starting $a -> $b lower sn3"

		orderparam-c3m arr4 "all and same residue as beta = [expr $i + 11]" ($a)to($b)_lower_sn3

		unset	arr1 arr2 arr3 arr4
	}
}
