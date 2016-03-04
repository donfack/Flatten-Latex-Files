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
my $commands = "";
my $theorems = "";
my $bibliographyStyle = "";
my $allBibliographies = Set::Scalar->new;
my $allMacros = Set::Scalar->new;
my $dependencyGraph = Graph->new;
my $root = 'root';
my $file = "";

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
	system("latex " . $rootFile . ".tex > latex.log");

	# init dependency graph
	$dependencyGraph->add_vertex($root);
}

sub flattenFile {
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

	while ( my $line = ($opened ? <$FHANDLE> : <> ) ) {
		chomp($line);
		
		# remove comments starting a line, remove the whole line
		if ($line =~ /^\s*(%.*)$/) {
			next;
		}
		# remove all other comments except for end of line, protect
		$line =~ s/^(.*?[^\\])(%.*)/$1/gi;		
		# remove \todo[xxx]{aaa}{bbb}, first and third are optional
		$line =~ s/\\todo\s*(\[.*?\])?\s*\{.*?\}\s*(\{.*?\})?//gi;
		
		# order the document
		if ($line =~ /^(.*)\\documentclass(\[.*\])?\{(.*?)\}(.*)$/) {
			$firstLine .= $line . "\n";
		}
		elsif ($line =~ /^(.*)\\(begin)\s*\{document\}(.*)$/) {
			$beforeBeginDocumentBool = 0;
			$afterBeginDocument .= $line . "\n";
		}
		# check for input statements, just one per line!!
		elsif ($line =~ /^(.*)\\(input)\s*\{(.*?)\}(.*)$/) {
			$allBibliographies->insert($3);
			flattenFile($3);
			$filelike .= (defined($4)?$4 ."\n" : "\n");
		} 
		elsif ($line =~ /^(.*)\\(include)\s*\{(.*?)\}(.*)$/) {
			$allBibliographies->insert($3);
			flattenFile($3);
			$filelike .= (defined($4)?$4 ."\n" : "\n");
		}
		# check for \usepackage[Paketoptionen]{Paketname}, first is optional
		elsif ($line =~ /^(.*)\\(usepackage)(\[.*?\])?\{(.*?)\}(.*)$/) {
			$usepackages .= $line . "\n";
		}
		# check for \bibliography{Name}
		elsif ($line =~ /^(.*)\\(bibliography)\{(.*?)\}(.*)$/) {
			# merge single bibliographies into one
			#$allBibliographies->insert($3);
		}
		# check for \bibliographystyle{Name}
		elsif ($line =~ /^(.*)\\(bibliographystyle)\{(.*?)\}(.*)$/) {
			$bibliographyStyle .= $line . "\n";
		}
		# check for \newcommand{\Name}[Anzahl]{Definition}, second is optional
		elsif ($line =~ /^(.*)\\(re)?newcommand\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}(.*)$/) {
			$commands .= $line . "\n";
			$dependencyGraph->add_edge($root,$3);
			$allMacros->insert($3);
		}
		# check for \newtheorem{Name}[Zählung]{Bezeichnung}[Gliederung] second and forth is optional
		elsif ($line =~ /^(.*)\\(re)?newtheorem\*?\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}(\[.*?\])?(.*)$/) {
			$theorems .= $line . "\n";
		} 
		elsif ($line =~ /^(.*)\\(end)\s*\{document\}(.*)$/) {
			$lastLine .= $line . "\n";
		}
		# no special line, just print it
		else {
			if ($beforeBeginDocumentBool){
				$beforeBeginDocument .= $line ."\n";
			} else{
				$afterBeginDocument .= $line ."\n";
			}		
		}
	}
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
	$string .= "% theorems" ."\n";
	$string .= $theorems ."\n";
	$string .= "% other" ."\n";
	$string .= $beforeBeginDocument ."\n";
	$string .= "% begin document" ."\n";
	$string .= $afterBeginDocument ."\n";
	$string .= "% bibliography" ."\n";
	$string .= "\\bibliography\{" . $targetFile . "\}" ."\n";
	$string .= $bibliographyStyle ."\n";
	$string .= $lastLine ."\n";
	return $string;
}

sub removeMacros {
	my $newFile = "";
	# iterate again to check whether a macro was used inside the document or in another macro
	my @lines = split /\n/, $filelike;
	
	foreach my $line (@lines) {
		chomp($line);
#		print "\n dcp0" . "$line \n";
		if ($line =~ /^(.*)\\(newcommand)\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}$/) {
			my $name = $3;
			my $def = $5;
			my $def1=$5;
			print "\n dcp2 " . $line;
			print "\n dcp1 " . $name;
			print "\n dcp0 " . "$def1 \n";

			if ($def =~ s/(\\\w+)\{?\}?//gi) {
#				print "\n dcp" . $name;
#				print "\n dcp0" . $def1;
#				print "\n dcp1" . $def;
#				print "\n dcp2" . "$1 \n";
				if ($allMacros->has($1)) {
					$dependencyGraph->add_edge($1,$name);			
				}
			}
		}
		elsif ($line =~ /(.*?)(\\\w+)[\s\{\[]$/) {
			foreach ($line =~ /(.*?)(\\\w+)(\{\w\})?$/) {
				# for each occurance of a macro: check whether it was defined in the preamble
				if ($allMacros->has($2)) {
						$dependencyGraph->add_edge($2,'text');			
				}		
			}
		}
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

	# remove all unused macros
	# remove empty lines
	my $prev_empty = 0;
	my $this_empty = 0;
	foreach my $line (@lines) {
		chomp($line);
		
		if ($line =~ /^(.*)\\(newcommand)\s*\{(.*?)\}\s*(\[.*?\])?\s*\{(.*)\}$/) {
			if ($usedMacros->has($3)) {
				$newFile .= $line . "\n";
				$this_empty = 0;
			}
			#else {
			#	# TODO: wieder rausnehmen, nur zu Testzwecken
    			#	$newFile .= "% " . $line . "\n";
			#}
		}
		else {
			$this_empty = ($line =~ /^\s*$/);
			if ($prev_empty && $this_empty) {
				$this_empty = $prev_empty;
			} else {
				$newFile .= $line . "\n";
			}
		}
		$prev_empty = $this_empty;
	}
	return $newFile;
}

sub writeFile{
	if($print) {
		print $file ;
		
	}
	else {
		my $FHANDLE = gensym();
		open($FHANDLE, "> $targetPath$targetFile.tex");
		print $FHANDLE $file;
	}
}

sub removeFiles{
	# remove temporary files
	system("mv " . $rootFile . ".tex " . $rootFile .  "_keep.tex");
	system("rm " . $rootFile . ".*");
	system("mv " . $rootFile . "_keep.tex " . $rootFile .  ".tex");
}
