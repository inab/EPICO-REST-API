#!/usr/bin/perl

use warnings 'all';
use strict;

use File::Temp qw();

if(scalar(@ARGV) >= 2) {
	my $input = shift(@ARGV);
	my $matrixFilename = shift(@ARGV);
	
	my $numProcessors = `grep processor /proc/cpuinfo | tail -n 1 | cut -f 2 -d ':' | tr -d ' '` + 1;
	my $maxProcessors = $numProcessors >> 1;

	my $header = undef;
	{
		my $temporalHeaderObj = File::Temp->new(TMPDIR => 1);
		my $temporalHeader = $temporalHeaderObj->filename();
		system("grep '^#' '$input' | sed 's/^#[^\t]*\t//' > '$temporalHeader'");
		
		if(open(my $HEAD,'<',$temporalHeader)) {
			$header = <$HEAD>;
			chomp($header);
			close($HEAD);
		} else {
			die;
		}
	}
	
	my %sampleColumns = ();
	{
		my $temporalBodyObj = File::Temp->new(TMPDIR => 1);
		my $temporalBody = $temporalBodyObj->filename();
		
		my $temporalUniqueSamplesObj = File::Temp->new(TMPDIR => 1);
		my $temporalUniqueSamples = $temporalUniqueSamplesObj->filename();
		
		my $fullHeader = '# '. $header;
		my $sampNumCol = 0;
		system("grep -v '^#' '$input' | sort -S 50% --parallel=$maxProcessors -k 2,2 > '$temporalBody'");
		{
			system("cut -f 1 '$temporalBody' | sort -S 50% --parallel=$maxProcessors -u > '$temporalUniqueSamples'");
			
			# Reading the unique samples
			if(open(my $SAMPNAM,'<',$temporalUniqueSamples)) {
				my $sampCol = 0;
				while(my $sampleId = <$SAMPNAM>) {
					chomp($sampleId);
					
					$sampleColumns{$sampleId} = $sampNumCol;
					$fullHeader .= "\t" . $sampleId;
					
					$sampNumCol++;
				}
				
				close($SAMPNAM);
			} else {
				die;
			}
		}
		
		# Reading the content
		my $currentGeneId;
		my $currentGeneName;
		if(open(my $DATA,'<',$temporalBody)) {
			if(open(my $MATRIX,'>:encoding(UTF-8)',$matrixFilename)) {
				print $MATRIX $fullHeader,"\n";
				
				my @dataMatrix = ();
				while(my $line = <$DATA>) {
					chomp($line);
					my($sample_id,$gene_id,$gene_name,$FPKM) = split(/\t/,$line);
					unless(defined($currentGeneId) && $currentGeneId eq $gene_id) {
						if(defined($currentGeneId)) {
							print $MATRIX join("\t",$currentGeneId,$currentGeneName,@dataMatrix),"\n";
						}
						
						# Setting up the next batch
						$currentGeneId = $gene_id;
						$currentGeneName = $gene_name;
						@dataMatrix = split(/\t/,"NA\t" x $sampNumCol);
					}
					
					$dataMatrix[$sampleColumns{$sample_id}] = $FPKM;
				}
				
				# Last case
				if(defined($currentGeneId)) {
					print $MATRIX join("\t",$currentGeneId,$currentGeneName,@dataMatrix),"\n";
				}
				
				close($MATRIX);
			} else {
				die;
			}
			
			close($DATA);
		} else {
			die;
		}
	}
} else {
	print STDERR "Usage: $0 {input_file_from_EPICO} {matrix_file}\n";
	exit 1;
}

