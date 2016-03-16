#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use English;
use Symbol qw( gensym );
use Graph;
use Set::Scalar;

# Global variable
my $rootFile = "";
#my $rootPath = "";
my $targetFile = "";
my $targetPath = "";
my $print = 0;
my $filelike = "";
my $firstLine = "";
my $beforeBeginDocumentBool = 1;
my $beforeBeginDocument = "";
my $afterBeginDocument = "";
my $lastLine = "";
my $usepackages = "";
############## List of macros. This is no exhausive and one can  complete
my $commands = "";
my $providecommands="";
my $environement = "";
my $theorems = "";
my $savebox="";
my $length="";
my $font="";
my $counter="";
my $glossaryentry="";
my $acronym="";

############## End list of macros
my $bibliographyStyle = "";
my $allBibliographies = Set::Scalar->new;
my $allMacros = Set::Scalar->new;
my $dependencyGraph = Graph->new;
my $root = 'root';
my $file = "";
############ zahlerAncolla #########
my $totalAUF=0;
my $totalZU=0;
# Function call
init();
flattenFile($rootFile);
mergeBib();
$filelike = sortFile();
$file = removeMacros();
writeFile();
removeFiles();

# Subroutines
sub init{
	# check arguments
	if (defined($rootFile)) {
		if ($ARGV[0] =~ /^(\~?\/.+\/)*(.+)\.tex$/) {
			$rootFile = $2;
			#if (defined($1)) {
			#	$rootPath = $1;
			#}
		} else {
 			die "No file.";
		}
	} else {
 		die "No file.";
	}
	if (defined($ARGV[1])) {
		if ($ARGV[1] =~ /^(\~?\/.+\/)*(.+)\.tex$/) {
			$targetFile = $2;
			if (defined($1)) {
				$targetPath = $1;
			}
		} else {
 			die "No file.";
		}
	} else {
 		$print = 1;
	}

	# create .aux files
	system("latex " . $rootFile . ".tex > latex.log"); # > latex.log");

	# init dependency graph
	$dependencyGraph->add_vertex($root);
}

sub flattenFile {
	my $zahler=0;
	#Here we define variable for multiple lines.
	my $line=""; # It can be one or more lines.
	my $isMultiline=0;
	# open file
	my $FHANDLE = gensym();
	my $opened = 0;
	if (@_>0) {
		my $filename = shift @_;
		if (!open($FHANDLE, '<', $filename)) {
			#open $FHANDLE  , '<', $rootPath . $filename . ".tex"
			open $FHANDLE  , '<',  $filename . ".tex"
  				or die  "Can't open '$filename'" . ": " . $OS_ERROR ;
		}
		$opened = 1;	
	} else {
		die "Not enough parameters";
	}
	
	while ( my $multiline = ($opened ? <$FHANDLE> : <> ) ) {
		$zahler++;
		chomp($multiline);
		
		# remove comments starting a line, remove the whole line
		if ($multiline =~ /^\s*(%.*)$/) {
			next;
		}
		# remove all other comments except for end of line, protect
		$multiline =~ s/^(.*?[^\\])(%.*)/$1/gi;		
		# remove \todo[xxx]{aaa}{bbb}, first and third are optional
		$multiline =~ s/\\todo\s*(\[.*?\])?\s*\{.*?\}\s*(\{.*?\})?//gi;
		
		$line.=$multiline; #when isMultiline is true, then line is a multiple lines.
		# order the document
		if ($line =~ /^(.*)\\documentclass(\[.*\])?\{(.*?)\}(.*)$/) {
			$firstLine .= $line . "\n";
			goto INITLINE;
		}
		elsif ($line =~ /^(.*)\\(begin)\s*\{document\}(.*)$/) {
			$beforeBeginDocumentBool = 0;
			$afterBeginDocument .= $line . "\n";
			goto INITLINE;
		}
		# check for input statements, just one per line!!
		elsif ($line =~ /^(.*)\\(input)\s*\{(.*?)\}(.*)$/) {
			$allBibliographies->insert($3);
			flattenFile($3);
			$filelike .= (defined($4)?$4 ."\n" : "\n");
			goto INITLINE;
		} 
		elsif ($line =~ /^(.*)\\(include)\s*\{(.*?)\}(.*)$/) {
			$allBibliographies->insert($3);
			flattenFile($3);
			$filelike .= (defined($4)?$4 ."\n" : "\n");
			goto INITLINE;
		}
		# check for \usepackage[Paketoptionen]{Paketname}, first is optional
		elsif ($line =~ /^(.*)\\(usepackage)(\[.*?\])?\{(.*?)\}(.*)$/) {
			$usepackages .= $line . "\n";
			goto INITLINE;
		}
		# check for \bibliography{Name}
		elsif ($line =~ /^(.*)\\(bibliography)\{(.*?)\}(.*)$/) {
			# merge single bibliographies into one
			#$allBibliographies->insert($3);
			goto INITLINE;
		}
		# check for \bibliographystyle{Name}
		elsif ($line =~ /^(.*)\\(bibliographystyle)\{(.*?)\}(.*)$/) {
			$bibliographyStyle .= $line . "\n";
			goto INITLINE;
		}
		# check for \(re)newcommand(*){\Name}[Anzahl]{Definition}, second and (...) arguments are optional

		#elsif ($line =~ /^(.*)\\(re)?newcommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}(.*)$/ism) {
		elsif ($line =~ /^(.*)\\(re)?newcommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
			$totalAUF= $5=~tr/\{/\{/;
			$totalZU= $5=~tr/\}/\}/;
			print "1      $3    =  $line \n $totalAUF    $totalZU\n ";	
			if($totalAUF==$totalZU){
				print "2      $3    =  $line \n\n ";					
				$commands .= $line . "\n";
				$dependencyGraph->add_edge($root,$3);
				$allMacros->insert($3);
				goto INITMULTILINE;
			}else{
				goto WEITERLINE;
			}
		}
		# check for \providecommand(*){\Name}[Anzahl]{Definition}, second and (...) arguments are optional
		elsif ($line =~ /^(.*)\\providecommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
			$totalAUF= $4=~tr/\{/\{/;
			$totalZU= $4=~tr/\}/\}/;
			if($totalAUF==$totalZU){
				$providecommands .= $line . "\n";
				$dependencyGraph->add_edge($root,$2);
				$allMacros->insert($2);
				goto INITMULTILINE;
			}else{
				goto WEITERLINE;
			}
		}
		# check for \(re)newenvironment(*){Name}[Anzahl]{Vorher}{Nachher}, second and (...) arguments are optional
		elsif ($line =~ /^(.*)\\(re)?newenvironment\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
			$totalAUF= ($5=~tr/\{/\{/)==($5=~tr/\}/\}/);
			$totalZU= ($6=~tr/\{/\{/)==($6=~tr/\}/\}/);
			if($totalAUF and $totalZU){
				$environement .= $line . "\n";
				$dependencyGraph->add_edge($root,$3);
				$allMacros->insert($3);
				goto INITMULTILINE;
			}else{
				goto WEITERLINE;
			}			
		}
		# check for \(re)?newtheorem{Name}[Zählung]{Bezeichnung}[Gliederung] second and forth is optional
		elsif ($line =~ /^(.*)\\(re)?newtheorem\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*(\[.*\])?\s*$/ism) {
			$theorems .= $line . "\n";
			$dependencyGraph->add_edge($root,$3);
			$allMacros->insert($3);
			goto INITMULTILINE;
		}
		# check for \(re)?newsavebox{\Name}
		elsif ($line =~ /^(.*)\\newsavebox\*?\s*\{(.*?)\}\s*$/ism) {
			$savebox .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}
		# check for \(re)?newlength{Name}
		elsif ($line =~ /^(.*)\\newlength\*?\s*\{(.*?)\}\s*$/ism) {
			$length .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}
		# check for \newfont(*){\cmd}{font description}
		elsif ($line =~ /^(.*)\\newfont\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
			$font .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}
		# check for \newglossaryentries(*){label}{setting}
		elsif ($line =~ /^(.*)\\newglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
			$glossaryentry .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}
		# check for \longnewglossaryentries(*){label}{setting}{description}
		elsif ($line =~ /^(.*)\\longnewglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
			$glossaryentry .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}		
		# check for \newacronym(*){label}{short}{long}
		elsif ($line =~ /^(.*)\\newacronym\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
			$acronym .= $line . "\n";
			$dependencyGraph->add_edge($root,$2);
			$allMacros->insert($2);
			goto INITMULTILINE;
		}
		elsif ($line =~ /^(.*)\\(end)\s*\{document\}\s*$/) {
			$lastLine .= $line . "\n";
			goto ENDflattenFile;
		}
		# no special line, just print it
		else {
			if ($beforeBeginDocumentBool){
				if($line=~/newcommand|providecommand|newtheorem|newenvironment|newsavebox|newlength|newfont|newglossaryentry|longnewglossaryentry|newacronym/i or $isMultiline){
					$isMultiline=1;
					goto WEITERLINE;
				}
				$beforeBeginDocument .= $line ."\n";
				goto INITLINE;
			} else{
				$afterBeginDocument .= $line ."\n";
				goto INITLINE;
			}		
		}
		INITMULTILINE:
			$isMultiline=0;
			$line="";
			next;
		INITLINE:
			$line="";
			next;
		WEITERLINE:
			$line.="\n";
			next;
	}
	ENDflattenFile:
}

sub mergeBib {
	my $auxFiles = $rootFile . ".aux ";
	while (defined(my $e = $allBibliographies->each)) { 
		$auxFiles .= $e . ".aux ";
	}
	system("bibtool -q -x " . $auxFiles . " -o " . $targetFile . ".bib");
}


sub sortFile {
	my $string .= $firstLine ."\n";
	$string .= "% packages" ."\n";
	$string .= $usepackages ."\n";
	$string .= "% commands" ."\n";
	$string .= $commands ."\n";
	$string .= "% providecommands" ."\n";
	$string .= $providecommands."\n";
	$string .= "% environements" ."\n";
	$string .= $environement ."\n";
	$string .= "% theorems" ."\n";
	$string .= $theorems ."\n";
	$string .= "% Savebox" ."\n";
	$string .= $savebox ."\n";
	$string .= "% lengths" ."\n";
	$string .= $length ."\n";
	$string .= "% fonts" ."\n";
	$string .= $font ."\n";
	$string .= "% counters" ."\n";
	$string .= $counter ."\n";
	$string .= "% glossaryentries" ."\n";
	$string .= $glossaryentry ."\n";
	$string .= "% acronyms" ."\n";
	$string .= $acronym ."\n";
	$string .= "% other" ."\n";
	$string .= $beforeBeginDocument ."\n";
	$string .= "% begin document" ."\n";
	$string .= $afterBeginDocument ."\n";
	$string .= "% bibliography" ."\n";
	$string .= $bibliographyStyle ."\n";
	$string .= "\\bibliography\{" . $targetFile . "\}" ."\n";
	$string .= $lastLine ."\n";
	return $string;
}
sub removeMacros {
	my $newFile = "";
	my $zahler=0;
	
	#Here we define variable for multiple lines.
	my $line=""; # It can be one or more lines.
	my $isMultiline=0; #It is 1 when there are more lines.
	$beforeBeginDocumentBool=1;
	# iterate again to check whether a macro was used inside the deocument or in another macro
	my @lines = split /\n/, $filelike;
	
	#my $counter=0;
	foreach my $multiline (@lines) {
		$zahler++;
		chomp($multiline);
		$line.=$multiline; #when isMultiline is true, then line is a multiple lines.
		if (not $beforeBeginDocumentBool){
			# for each occurance of a macro: check whether it was be used in the text
			if ($line =~ /(.*?)(\\\w+)(.*?)$/) { 
				while($line =~ /(\\[a-zA-Z]+)/ig){
					if ($allMacros->has($1)) {
						$dependencyGraph->add_edge($1,'text');
					}
				}
			}
			# for each occurance of a macro environement or theorem: check whether it was be used in the text
			if ($line =~ /(.*?)\\begin\s*\{([a-zA-Z*]+)\}(.*?)$/) { 
				while($line =~ /\\begin\s*\{([a-zA-Z*]+)\}/ig){
					if ($allMacros->has($1)) {
						$dependencyGraph->add_edge($1,'text');
					}
				}
			}
			# for each occurance of a macro glassary or acronym: check whether it was be used in the text
			if ($line =~ /(.*?)(gls|Gls|glspl|Glspl|glssymbol)\*?\{(\w+\w*)\}(.*?)$/) { 
				while ($line =~ /(gls|Gls|glspl|Glspl|glssymbol)\*?\{(\w+\w*)\}/gi) { 
					if ($allMacros->has($2)){					
						$dependencyGraph->add_edge($2,'text');
					}
				}
			}

			goto INITLINE;
		}else{

			if ($line =~ /^(.*)\\(re)?newcommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
				$totalAUF= $5=~tr/\{/\{/;
				$totalZU= $5=~tr/\}/\}/;
				if($totalAUF==$totalZU){
					my $name = $3;
					my $def = $5;
					while ($def =~ /(\\\w+\w*)/gi) { 
						if ($allMacros->has($1)){					
							$dependencyGraph->add_edge($1,$name);
						}
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
			}
			elsif ($line =~ /^(.*)\\providecommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
				$totalAUF= $4=~tr/\{/\{/;
				$totalZU= $4=~tr/\}/\}/;
				if($totalAUF==$totalZU){
					my $name = $2;
					my $def = $4;
					while ($def =~ /(\\\w+\w*)/gi) { 
						if ($allMacros->has($1)){					
							$dependencyGraph->add_edge($1,$name);
						}
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
			}
			elsif($line =~ /^(.*)\\(re)?newenvironment\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				$totalAUF= ($5=~tr/\{/\{/)==($5=~tr/\}/\}/);
				$totalZU= ($6=~tr/\{/\{/)==($6=~tr/\}/\}/);
				if($totalAUF and $totalZU){
					my $name = $3;
					my $defBefore = $5;
					my $defAfter = $6;
					while ($defBefore =~ /(\\\w+\w*)/gi) { 
						if ($allMacros->has($1)){					
							$dependencyGraph->add_edge($1,$name);
						}
					}
					while ($defAfter =~ /(\\\w+\w*)/gi) { 
						if ($allMacros->has($1)){					
							$dependencyGraph->add_edge($1,$name);
						}
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
				

			}
			elsif ($line =~ /^(.*)\\(re)?newtheorem\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*(\[.*?\])?\s*$/ism) {
				my $name = $3;
				my $def = $5;
				while ($def =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}
			# check for \savebox{\Name}[width][position]{content}
			elsif ($line =~ /^(.*)\\savebox\*?\s*\{(.*?)\}\s*(\[.*\])?\s*(\[.*\])?\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $def = $5;
				while ($def =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}
			# check for \sbox{\Name}{content}
			elsif ($line =~ /^(.*)\\sbox\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $def = $3;
				while ($def =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}
			# check for \newfont(*){\cmd}{font description}
			elsif ($line =~ /^(.*)\\newfont\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $def = $3;
				while ($def =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}
			# check for \newglossaryentries(*){label}{setting}
			elsif ($line =~ /^(.*)\\newglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $def = $3;
				while ($def =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;				
			}
			# check for \longnewglossaryentries(*){label}{setting}{description}
			elsif ($line =~ /^(.*)\\longnewglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $defSetting = $3;
				my $defDescription=$4;
				while ($defSetting =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				
				while ($defDescription =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}		
			# check for \newacronym(*){label}{short}{long}
			elsif ($line =~ /^(.*)\\newacronym\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				my $name = $2;
				my $defShort = $3;
				my $defLong=$4;
				while ($defShort =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				
				while ($defLong =~ /(\\\w+\w*)/gi) { 
					if ($allMacros->has($1)){					
						$dependencyGraph->add_edge($1,$name);
					}
				}
				goto INITMULTILINE;
			}
			elsif ($line =~ /^(.*)\\(begin)\s*\{document\}\s*$/) {
				$beforeBeginDocumentBool = 0;
				goto INITLINE;
			}
			else{

				if($line=~/newcommand|providecommand|newtheorem|newenvironment|newsavebox|newlength|newfont|newglossaryentry|longnewglossaryentry|newacronym/i or $isMultiline){
					$isMultiline=1;
					$line.="\n";
					next;
				}else{

					# for each occurance of a macro: check whether it was defined in the preamble
					if ($line =~ /(.*?)(\\\w+)(.*?)$/) { 
						while($line =~ /(\\[a-zA-Z]+)/ig){
							if ($allMacros->has($1)) {
								$dependencyGraph->add_edge($1,'text');
							}
						}
					}
					# for each occurance of a macro environement or theorem: check whether it was defined in the preamble
					if ($line =~ /(.*?)\\begin\s*\{([a-zA-Z*]+)\}(.*?)$/) { 
						while($line =~ /\\begin\s*\{([a-zA-Z*]+)\}/ig){
							if ($allMacros->has($1)) {
								$dependencyGraph->add_edge($1,'text');
							}
						}
					}
					goto INITLINE;
				}
			}
		}
		INITMULTILINE:
			$isMultiline=0;
			$line="";
			next;
		INITLINE:
			$line="";
			next;
		WEITERLINE:
			$line.="\n";
			next;
	}
	# remove unused macros
	# if there is no path between the 'text' node and the macro-node, the macro is never used
	my $usedMacros = $allMacros->copy;
	my $apsp = $dependencyGraph->APSP_Floyd_Warshall();
	while (defined(my $e = $allMacros->each)) {	
		my $l = $apsp->path_length($e, 'text');
		unless ($l) {
			$usedMacros->delete($e);
		}
	}
	#Here we define variable for multiple lines.
	$line=""; # It can be one or more lines.
	$isMultiline=0; #It is 1 when there are more lines.
	$beforeBeginDocumentBool = 1;
	# remove all unused macros
	# remove empty lines
	my $prev_empty = 0;
	my $this_empty = 0;
	foreach my $multiline (@lines) {
		chomp($multiline);
		$line.=$multiline; #when isMultiline is true, then line is a multiple lines.
		if(not $beforeBeginDocumentBool){
			$this_empty = ($line =~ /^\s*$/);
			if ($prev_empty && $this_empty) {
				$this_empty = $prev_empty;
			} else {
				$newFile .= $line . "\n";
			}
			goto INITLINE;
		}
		else{
			if ($line =~ /^(.*)\\(re)?newcommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
				$totalAUF= $5=~tr/\{/\{/;
				$totalZU= $5=~tr/\}/\}/;
				if($totalAUF==$totalZU){
					#print "True Macro $line \n $totalAUF $totalZU  \n";					
					if ($usedMacros->has($3)) {
						#print "True Macro $line \n";
						$newFile .= $line . "\n";
						$this_empty = 0;
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
			}
			elsif ($line =~ /^(.*)\\providecommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*$/ism) {
				$totalAUF= $5=~tr/\{/\{/;
				$totalZU= $5=~tr/\}/\}/;
				if($totalAUF==$totalZU){
					if ($usedMacros->has($2)) {
						$newFile .= $line . "\n";
						$this_empty = 0;
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
			}
			elsif($line =~ /^(.*)\\(re)?newenvironment\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				$totalAUF= ($5=~tr/\{/\{/)==($5=~tr/\}/\}/);
				$totalZU= ($6=~tr/\{/\{/)==($6=~tr/\}/\}/);
				if($totalAUF and $totalZU){
					if ($usedMacros->has($3)) {
						$newFile .= $line . "\n";
						$this_empty = 0;
					}
					goto INITMULTILINE;
				}else{
					goto WEITERLINE;
				}
			}
			elsif ($line =~ /^(.*)\\(re)?newtheorem\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}\s*(\[.*?\])?\s*$/ism) {
				if ($usedMacros->has($3)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}
			# check for \(re)?newsavebox{\Name}
			elsif ($line =~ /^(.*)\\newsavebox\*?\s*\{(.*?)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}
			# check for \(re)?newlength{Name}
			elsif ($line =~ /^(.*)\\newlength\*?\s*\{(.*?)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}
			# check for \newfont(*){\cmd}{font description}
			elsif ($line =~ /^(.*)\\newfont\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}
			# check for \newglossaryentries(*){label}{setting}
			elsif ($line =~ /^(.*)\\newglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}
			# check for \longnewglossaryentries(*){label}{setting}{description}
			elsif ($line =~ /^(.*)\\longnewglossaryentry\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}		
			# check for \newacronym(*){label}{short}{long}
			elsif ($line =~ /^(.*)\\newacronym\*?\s*\{(.*?)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/ism) {
				if ($usedMacros->has($2)) {
					$newFile .= $line . "\n";
					$this_empty = 0;
				}
				goto INITMULTILINE;
			}			
			elsif ($line =~ /^(.*)\\(begin)\s*\{document\}\s*$/) {
				$beforeBeginDocumentBool = 0;
				$newFile .= $line . "\n";
				goto INITLINE;
			}
			else{
				if($line=~/newcommand|providecommand|newtheorem|newenvironment|newsavebox|newlength|newfont|newglossaryentry|longnewglossaryentry|newacronym/i or $isMultiline){
					$isMultiline=1;
					$line.="\n";
					next;
				}else{
					$this_empty = ($line =~ /^\s*$/);
					if ($prev_empty && $this_empty) {
						$this_empty = $prev_empty;
					} else {
						$newFile .= $line . "\n";
					}
				}
				goto INITLINE;
			}
		}
		INITMULTILINE:
			$isMultiline=0;
			$line="";
			$prev_empty = $this_empty;
			next;
		INITLINE:
			$line="";
			$prev_empty = $this_empty;
			next;
		WEITERLINE:
			$line.="\n";
			next;
	}
	return $newFile;
}

sub writeFile{
	if($print) {
		open (my $fh, '>', "latex.tex");
		print $file;
		close($fh);
	}
	else {
		my $FHANDLE = gensym();
		open($FHANDLE, "> $targetPath$targetFile.tex");
		print $FHANDLE $file;
		#close ($FHANDLE);
	}
}

sub removeFiles{
	# remove temporary files
	system("mv " . $rootFile . ".tex " . $rootFile .  "_keep.tex");
	system("rm " . $rootFile . ".*");
	system("mv " . $rootFile . "_keep.tex " . $rootFile .  ".tex");
}
