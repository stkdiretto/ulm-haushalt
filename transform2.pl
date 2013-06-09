#!/usr/bin/perl

# To the extent possible under law, Stefan Kaufmann has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland. See https://creativecommons.org/publicdomain/zero/1.0/ for details.

use strict;
use warnings;
use utf8;
use Text::CSV;

my $csv = Text::CSV->new({binary=>1});
my $out;

# Produktbereiche by IDs as from http://www.ulm.de/politik_verwaltung/rathaus/ueberblick.3581.3076,3571,3744,3521,4132,3581.htm (See complete Haushalt of 2012, Anlage 8 for comparison. This is page 498 of the PDF document http://www.ulm.de/statistik/download.php?file=L3NpeGNtcy9tZWRpYS5waHAvMjkvRWNodGF1c2RydWNrJTIwMjAxMiUyMGtvbXBsZXR0LnBkZg==)
my %pdbId = (
  "11" => "Innere Verwaltung",
  "12" => "Sicherheit und Ordnung",
  "21" => "Schultraegeraufgaben",
  "25" => "Museen, Archiv, Zoo",
  "26" => "Theater, Musikschule",
  "27" => "VH, Bibliothek, kult-paed.Einrichtungen",
  "28" => "sonstige Kulturpflege",
  "31" => "Soziale Hilfen",
  "36" => "Kinder-, Jugend- und Familienhilfe",
  "41" => "Gesundheitsdienste",
  "42" => "Sport und Baeder",
  "51" => "Raeumliche Planung und Entwicklung",
  "52" => "Bauen und Wohnen",
  "53" => "Ver- und Entsorgung",
  "54" => "Verkehrsflaechen und -anlagen, OePNV",
  "55" => "Natur- und Landschaftspflege, Friedhofswesen",
  "56" => "Umweltschutz",
  "57" => "Wirtschaft und Tourismus",
  "61" => "Allgemeine Finanzwirtschaft"
);

 open ($out, ">","transformed.csv") or die "something even more terrible happened while opening output files: $!";
 print $out "uid,Produktbereich,Produktbereich Langfassung,Produktgruppe,Produktteilhaushalt,Produktteilhaushalt Langfassung,VwV-ID,VwV-Doppik Langfassung,amount,time,direction\n"; # header line of csv output file


foreach my $file (@ARGV) {
 process($file);
}

sub process {
 my $arg = shift;
 open (CSV, "<", "$arg") or die("Could not open inputfile: $!");
 open ($out, ">>","transformed.csv") or die "something even more terrible happened while opening output files: $!";


 my $document;
 my $pdb;
 my $pdg;
 my $teilhh;
 my $vwvId;
 my $vwvName;
 my $counter = 0;

 while(<CSV>) {
    next if ($. == 1); # skip first line of csv file
    if ($csv->parse($_)) {
      my @columns = $csv->fields();

       # Setup of input: $columns[n], with 0: Anlagen, 1: Produkt-Teilhaushalt, 2: Produkt-Teilhaushalt Langtext,
       # 3: Kontenbeschreibung nach VwV-Doppik, 4: Plan 2012, 5: Plan 2011, 6: Ist 2010

      # Split "Produktteilhaushalt" into Produktbereich, Produktgruppe and Teilhaushalt

      if ($columns[1] =~ m/-/) {         # if "Produktteilhaushalt" contains a hyphen (needs different treatment otherwise)
        my @pdbpdg = split(/-/,$columns[1]); # split along hyphen
        $pdb = substr($pdbpdg[0],0,2);   # first two characters of first number group is Produktbereich
        $pdg = $pdbpdg[0];               # Produktbereich with following two characters is Produktgruppe
        $teilhh = $pdbpdg[0] . $pdbpdg[1]; # Teilhaushalt        
      } else {                           # Produktteilhaushalt w/out hyphen (don't know the reason for that oO)
        $pdb = substr($columns[1],0,2);  # This is correct
        $pdg = substr($columns[1],0,4);  # This might also be correct
        $teilhh = $columns[1] ;          # This is a guess
      }

      # Split "Kontenbeschreibung nach VwV-Doppik" into numeric ID of transaction and plaintext explanation
      if ($columns[3] =~ m/\)/) {       # layout: "01) blablubb"
      $vwvId = substr($columns[3],0,2); # first two digits before the closing bracket
      $vwvName = substr($columns[3],4); # everything past the whitespace
      } else {                          # no VwV-Doppik-Id given, take full 3rd column and leave ID empty
      $vwvId = "";                      # This happens with the Investivhaushalt 2011/12. We don't know why this is the case.
      $vwvName = $columns[3];
      }



			if ($vwvId > 0 && $vwvId < 10) { # VwV-ID is 1..9: Ertraege
			$columns[4] =~ s/-//;
			print $out "$columns[1]$counter,$pdb,\"$pdbId{$pdb}\",$pdg,$teilhh,\"$columns[2]\",$vwvId,\"$vwvName\",$columns[4],2012,Ertrag\n";

      $counter += 1;	

			} elsif ($vwvId == 18) { #interne Buchungen
					if ( $columns[4] > 0 ) { #Ertraege
			      $columns[4] =~ s/-//;
						print $out "$columns[1]$counter,$pdb,\"$pdbId{$pdb}\",$pdg,$teilhh,\"$columns[2]\",$vwvId,\"$vwvName\",$columns[4],2012,Ertrag\n";
					} else { # Aufwendungen
						print $out "$columns[1]$counter,$pdb,\"$pdbId{$pdb}\",$pdg,$teilhh,\"$columns[2]\",$vwvId,\"$vwvName\",$columns[4],2012,Aufwendung\n";

					}

			} else { # VwV-ID is 10...16 or 19..20: Aufwendungen
			print $out "$columns[1]$counter,$pdb,\"$pdbId{$pdb}\",$pdg,$teilhh,\"$columns[2]\",$vwvId,\"$vwvName\",$columns[4],2012,Aufwendung\n";

      $counter += 1;	
			}


    } else {
      my $err = $csv->error_diag;
      print "Failed to parse line: $err";
    }
  }

close CSV;
close $out;
}

