#!/opt/local/bin/perl
###########################################################################
###########################################################################
#
# SRC2HTML.
#
# Generation of code browsing HTML pages from source files with
# cross-references of identifiers (macros, functions, global variables,
# aka "tags").
#
# MODIFICATION HISTORY:
# ---------------------
# 0.4  13 Aug 2004 - CPot: first release
#
# 0.5     Feb 2005 - CPot:
#   Fixed issue for tags with different case. Specify title of page.
#   References in alphabetical order. List C++ destructors.
#   Allow filenames and paths containing spaces.
#   Alphabetical order, not ASCII "uppercase-first" order.
#   (IMPLEMENTATION) All info about a tag is unified in a single global
#   'tagInfo' hash table.
#
# 0.6     Mar-Aug 2005 - CPot:
#   Removed perl warnings (almost all). Fixed the script warning if destDir
#   is not empty.
#   Option "-i" to warn about (and list) include files that are not found.
#   Fall back to use plain "ctags" if ctags not found in script dir.
#   Link the function prototype if there is no function definition.
#   Same for variable declaration and definition.
#   Don't use a struct, union enum name as definition if there is also the
#   "typedef" for the same.
#   Added version in HTML page.
#   Include size of auxiliary html pages in total count.
#   Don't create dest directory if no input file.
#   Don't use $MATCH/$PREMATCH/$POSTMATCH to improve performances.
#   splitpath() now correctly handles backslashes under MSWin32
#   (Optionally) generate valid HTML.
#   Source files that are derived objects now will be processed.

my $currentVersion="0.6b11 - Aug 2005";

#
# TO DO LIST:
# -----------
#
# *) Remove unprintable chars from source code.
#
# *) Add C++ include files with no extension ("iostream", "string" etc)
#
# *) Add command used to generate the output to HTML pages.
#
# *) Streamline hash tables with filenames.
# 
# *) Test more the ASM, (Java, perl?) synatx.
#
# *) "//" comments do not work if the line contains a /* */ comment
#    before "//". And they should be checked only for cpp files
#
# *) divide top frame in two (Show current filename in frame 
#    above source using JavaScript?)
#
# *) if multiple include files with same name, try to link to
#    appropriate file in an "include" line and not the first one
#
# *) verify if other "HTML forbidden" chars beside <,> and &
#
# *) Option for not copying source files? Possible only if using
#    simple file list and paths without spaces, as ctags doesn't
#    understand clearcase pathnames and spaces in the path
#
#
#
#
# USAGE AND VERSION NUMBER:
# -------------------------
# See message printed by the function "usageAndTerminate()" (at the end
# of this file).
#
#
# NOTES:
# ------
# To run requires the "Exuberant Ctags" utility (see the message in
# "usageAndTerminate()" function for details).
#
# GNU ctags (or similar) cannot be used because it doesn't support
# specifying the input files in a list (-L option of Exuberant Ctags)
#
# The utility  can be in the same directory as this very perl script
# and its name must be "ctags_$OSNAME", i.e, "ctags_solaris",
# "ctags_MSWin32.exe", "ctags_hpux", ... depending on the architecture.
# Note that for cygwin, the executable name must be "ctags_MSWin32.exe"
# and not "ctags_cygwin.exe"
# If "ctags_$OSNAME" is not found, plain "ctags" (in the same directory)
# will be attempted.
# If this doesn't exist as well, plain command "ctags" will be attempted.
#
# So if you have exuberant ctags installed in your system as "ctags",
# you don't need anything else.
#
#
# IMPROVEMENTS FROM IAN RAE'S "C" VERSION:
# ----------------------------------------
#
# *) Handles properly multiple files with same names.
#
# *) Handles properly duplicate tags
#
# *) Improved handlings of tags (uses latest version of 'ctag' utility)
#
# *) Correctly escapes "&" chars
#
# *) Run from HP UX, Windows, Solaris
#
# *) Runs directly from catcr output and from multiple inputs.
#
# *) line numbers
#
# *) full path in file list
#
# *) In Perl (!?!), commented.
#
# *) ctags runs externally, easier to upgrade to latest
#
# *) meaningful title of HTML page
#
#
#
# OTHER KNOWN BUGS/PROBLEMS:
# --------------------------
# Restriction on filenames: they cannot contain the "#" and "@" chars.
# Restriction on paths: they cannot contain the "\" and "@" chars.
# This works well when you have at most a few hundred source files.
# When you have in the order of several thousands files, the index
# pages become too big and slow.
# Also, if you have many files with the same name, using a single flat
# list of files is not the best way of organizing them.
#
#
# HOW IT WORKS:
# -------------
# 
# 1) Input parameters are scanned and a list (possibly quite big) of all
#    source files to use is built in the hash '%filelist'
# 
# 2) All source files found are copied in the destination directory.
#    The names of the files, as copied in the dest direcory, might be
#    modified ('mangled') if they contain spaces or if there are
#    duplicate names.
#    Also, a file named 'filenamelist.txt' is created in the same directory,
#    listing all the files.
# 
# 3) The external 'ctags' utility is called, passing to it "filenamelist.txt".
#    'ctags' creates a file named 'tags' that specifies where all "tags"
#    (functions, types, variables etc) are DEFINED (i.e. NOT where they are
#    used).
#    The content of the 'tags' file is then read in memory in the hash
#    '%tagInfo'.
# 
# 4) Now each source file is scanned, line by line, to find where the tags
#    are USED. The parsing in NOT very rigorous: every time something that
#    looks like an identifier is found ouside of a comment, the '%tagInfo'
#    hash is searched to see if it is there.
#    This part is language dependent, so there is a function for C/C++/Java,
#    one for ASM and one for Perl
#    When a place is found where an identifier is used, this is added to
#    the '%tagInfo' hash, for later use.
#    While scanning the source file, the corresponding HTML file is
#    generated line by line.
# 
# 5) When all source files have been scanned, the HTML indices for the each
#    letter is created, using the info in the '%tagInfo' table.
# 
# 6) Finally the other HTML frames are generated and all the copied source
#    files are deleted.
# 
# Note that step 2 (copying all the files) is needed because 'ctags' does not
# work with clearcase extended pathnames (otherwise it could have been
# avoided). Also ctags doesn't work with paths containing spaces and copying
# solves this too.
#
#
#
# OTHER TOOLS THAT YOU MIGHT WANT TO USE INSTEAD OF THIS ONE:
# -----------------------------------------------------------
#
# 'GNU GLOBAL Source Code Tag System' by Shigio Yamaguchi
# http://www.gnu.org/software/global/manual/global.html
#
#
# 'LXR'
# http://sourceforge.net/projects/lxr
# http://lxr.linux.no/
#
###########################################################################
###########################################################################

my $start_time=time();

use strict;
use English qw( -no_match_vars );

use File::Copy;
use File::stat;
use File::Spec;
use Cwd;


# prototypes to avoid warnings
sub usageAndTerminate($);
sub splitpath($);
sub findAbsPath($);
sub flattenCatCr($$);
sub scanForTagsAsm($);
sub scanForTagsC($);
sub scanForTagsPerl($);
sub createOtherHTMLPages();
sub createAlhpabeticalIndices();
sub scanDirectory($$);





# Which file extension maps to which language
my %map_ext_to_lang = (
  ".c"     => "c",
  ".h"     => "c",
  ".cc"    => "c",
  ".hh"    => "c",
  ".cpp"   => "c",
  ".hpp"   => "c",
  ".java"  => "java",
  ".s"     => "asm",
  ".S"     => "asm",
  ".asm"   => "asm",
  ".pl"    => "perl",
  ".pm"    => "perl",
);



# If the following 'styles' are used, the HTML pages produced will not
# be valid HTML.
# Internet Explorer does not recognize that the HTML syntax is invalid
# though, so these can be used with IE.
# These 'styles' should really be removed but are still here to maintain
# compatibility with the look to which people are now used.
# Using the "-v" option on the command line will override these styles
# and the pages will be 100% valid HTML 4.0.

# style used for comments
my $COMMENT_STYLE_BEGIN='<FONT COLOR="A0A0A0">';
my $COMMENT_STYLE_END='</FONT>';

# style used for line numbers
my $LINENUM_STYLE_BEGIN='<FONT COLOR="D0D0D0">';
my $LINENUM_STYLE_END='</FONT>';

# Style used for links (to the tags definitions and references)
my $TAG_COLOR='"FF0000"';
my $TAG_STYLE_BEGIN="<FONT COLOR=$TAG_COLOR>";
my $TAG_STYLE_END='</FONT>';




#---------------------------------------------------------------------
#            %tagInfo hash, main global data structure:
#
# The KEY is the tag name.
# The VALUE is a reference to an array:
#
# +-----+
# |  *  | $tagInfo{"tagname"}
# +--|--+  
#    |                      Where "tagname" is DEFINED
#    |                      (from 'tags' file generated by ctags):
#    +->+-----+            +----------------+
#     0 |  *--+----------->| "file1.c#12#f" |
#       +-----+            +----------------+------+
#     1 |  *--+----+       | "another_file.h#45#p" |
#       +-----+    |       +-----------------------+
#     2 | 123 |    |
#       +-----+    |      Where "tagname" is USED (generated 
#                  |      by this script by scanning the sources):
#                  |     +--------------+
#                  +---->| "f1.cpp#223" |
#                        +-----------+--+
#                        | "f2.c#12" |
#                        +-----------+
#
# NOTE: positions in the files are described by a string of type:
#       "f1.html#223": filename + line number.
#
# ${$tagInfo{$tagname}}[0]:
# is a reference to an array containing the location(s) where this tag is
# DEFINED and its type (as reported by ctags). So this array will contain
# strings of the form "sourcefile.c#123#f".
#
# ${$tagInfo{$tagname}}[1]:
# is a reference to an array containing the location(s) where this tag is
# REFERENCED (used).
#
# ${$tagInfo{$tagname}}[2]:
# is the tag ID (a number).
# Each tag must have a tag ID (just an identifying number assigned in
# incrementing order for each tag found).
# This is needed to be able to jump to the tag definition in the
# alphabetical index pages because the <HREF NAME="xxx"> is case
# insensitive and so the tagname itself cannot be used
#
my %tagInfo;


my $path_separator = ($OSNAME eq "MSWin32")? "\\" : "/";


# These are read from the command line
my ($onlyPrintFileList,$dstDir);
my (@allInputFiles,@inputFileTypes);
my $warnIncludesNotFound=0;



# A couple of temporary file names
my $tagfile="tags";
my $namelist="filenamelist.txt";



# string to use as title for the mainpage
my $page_title="";




# -------- let's analyze the command line parameters

(@ARGV >= 2) || usageAndTerminate("  ERROR: not enough arguments\n");




my $lastOne=@ARGV-1; # very last arg is the output directory

$dstDir=$ARGV[$lastOne];


my $k=0;
while ($k<$lastOne) {
  my $isInputFile=0;
  
  if ( ($ARGV[$k] eq "-c") || ($ARGV[$k] eq "-C") || ($ARGV[$k] eq "-l") ||
       ($ARGV[$k] eq "-d") || ($ARGV[$k] eq "-D") || ($ARGV[$k] eq "-F") ) {
    usageAndTerminate("") if ($k>=($lastOne-1)); # another param must follow!
    $isInputFile=1;

  } elsif ($ARGV[$k] eq "-f") {
    $onlyPrintFileList=1;

  } elsif ($ARGV[$k] eq "-z") {
    print "  WARNING: '-z' option not supported\n";

  } elsif ($ARGV[$k] eq "-t") {
    $page_title=$ARGV[$k+1];
    $k++;

  } elsif ($ARGV[$k] eq "-i") {
    $warnIncludesNotFound=1;

  } elsif ($ARGV[$k] eq "-v") {
    $COMMENT_STYLE_BEGIN="<I>";
    $COMMENT_STYLE_END="</I>";
    $LINENUM_STYLE_BEGIN="<I>";
    $LINENUM_STYLE_END="</I>";
    $TAG_STYLE_BEGIN="";
    $TAG_STYLE_END="";
  }

  if ($isInputFile) {
    my $inputfile=$ARGV[$k+1];


    if ( ($ARGV[$k] eq "-d") || ($ARGV[$k] eq "-D") ) {
      if ( !(-d $inputfile) ) {
        print "  WARNING: specified directory <$inputfile> doesn't exist or is not a directory ($ERRNO).\n";
        $inputfile=undef;
      }
    } elsif ( !(-f $inputfile) ) {
      print "  WARNING: specified file <$inputfile> doesn't exist or is not a file ($ERRNO).\n";
      $inputfile=undef;
    }

    if ($inputfile) {
      $allInputFiles[@allInputFiles]   = $inputfile;
      $inputFileTypes[@inputFileTypes] = $ARGV[$k];
    }
    $k+=2;
  } else {
    $k++;
  }

} # while ($k)


usageAndTerminate("  ERROR: No input file specified\n") if (@allInputFiles==0);


# If no title was specified on the command line, use as a title
# the name (without path) of the first input file
if ($page_title eq "") {
  my $first_input=$allInputFiles[0];
  my ($v,$dir,$filename)=splitpath($first_input);
  # if empty, it was a directory name, terminating with "/"; take last dir name
  ($v,$dir,$filename)=splitpath(substr($dir,0,-1)) if ($filename eq "");
  $page_title = "<$filename> - Source Code Browser" 
}



# pathname to the ctag utility
my $ctags_executable;



if (!$onlyPrintFileList) {

  # ------ Do we have a ctag executable in the same directory as this program?

  # find the directory where this program is 
  $PROGRAM_NAME =~ /.*[\/\\]/;  # match longest string that terminates with / or \
  my $program_dir=findAbsPath($&); # convert to an absolute path

  # The executable for cygwin is the same as for MSWIN32
  my $osname= ($OSNAME eq "cygwin")?  "MSWin32" : $OSNAME;
  $ctags_executable="$program_dir/ctags_$osname";
  $ctags_executable.=".exe" if ($osname eq "MSWin32");


  # if the executable doesn't exists with that name, let's fall back to
  # "ctags" in the same directory
  if (! -x $ctags_executable) {
    my $extension=($OSNAME eq "cygwin")? ".exe" : ""; # pesky "EXE" extension!
    $ctags_executable="$program_dir/ctags";
    $ctags_executable.=".exe" if ($osname eq "MSWin32");
  }

  # It it still doesn't exist, we will try to run the system installed
  # "ctags" command. If this does not exists or is not the 'Exuberant Ctags'
  # version, we will fail miserably later
  if (! -x $ctags_executable) {
    print "  WARNING: Local 'ctags' executable not found, will try to use 'ctags' command";
    $ctags_executable="ctags";
  }


  # ------ Does dest. directory exist? If not, try to create it.

  -d $dstDir   || mkdir $dstDir,0777;  # try to create dir if doesn't exist
  -d $dstDir   || die "  ERROR: cannot create destination directory <$dstDir>. Terminating";

  opendir DSTDIR,$dstDir  || die "  ERROR:Cannot read directory <$dstDir>. Terminating";
  my @dirlist=readdir(DSTDIR);
  print "  WARNING: destination directory $dstDir is not empty. Files with the same name will be overwritten.\n" if (@dirlist!=2);
  closedir DSTDIR;

}




# ------- Generate the list of all source files in the hash named %filelist
# ------- The hash will have as KEY the full path of the file. The VALUE
# ------- doesn't matter.
# ------- We use an hash instead of an array so that if we have the same path
# ------- twice or more, we store it only once.

my %filelist;

for (my $k=0;$k<@allInputFiles;$k++) {
  my @allLines;
  my $keepTheFile;
  my $file=$allInputFiles[$k];
  my $type=$inputFileTypes[$k];

  # Split $file in its components
  my ($vol,$dir,$basename)=splitpath($file);

  my $listname=undef;

  if ($type eq "-c") {
    (`cleartool ls -l $file` =~ /^derived object/) || printf("  WARNING: specifed file <$file> is not a Clearcase derived object\n");
    # it is a Clearcase derived object, let's make the catcr list

    # Use appropriate path separator, for the system command only
    my $catcr_output="$dstDir$path_separator$basename.catcr";
    $listname = "$dstDir/$basename.list";

    print "Executing \"cat cr\" on $file to get the list of source files...\n";
    system("cleartool catcr -flat $file > $catcr_output");

    flattenCatCr($catcr_output,$listname);

    unlink $catcr_output;

  } elsif ($type eq "-C") {  # it is a text file containing a catcr output

    $listname = "$dstDir/$basename.list";

    flattenCatCr($file,$listname);

  } elsif ($type eq "-l") {  # it is a text file containing a list of files

    $listname=$file;
    $keepTheFile=1;

  } elsif ( ($type eq "-d") || ($type eq "-D") ) {  # it is a directory

    my $recursive = ($type eq "-D");

    my @dir_files = scanDirectory($file,$recursive);

    if (@dir_files) {
      $listname = "$dstDir/$basename.list";

      open OUTFILE,">$listname" || die "  ERROR: Cannot open <$listname> ($ERRNO). Terminating";
      foreach (@dir_files) {
        my $extension = $1 if (/(\.[^\.]*)$/);

        if ($map_ext_to_lang{$extension}) {
          print OUTFILE "$_\n";
        }
      }
      close OUTFILE;
    }

  } elsif ($type eq "-F") { # it is a single source file directly specified

    if (-f $file) {
      $filelist{$file}=0; # The VALUE doesn't matter.
    } else {
      print "  WARNING: File <$file> doesn't exist or is not a normal file ($ERRNO)\n";
    }

  } else {
    die "  ERROR: type of input is wrong\n";
  }


  # We accumulated all file names in a file; we now transfer those names
  # in the hash in memory.
  if ($listname) {
    open(INFILE,$listname) || print "  WARNING: Cannot open list: $listname ($ERRNO)\n";
    my @allLines=<INFILE>;
    close INFILE;
    unlink $listname unless $keepTheFile;

    foreach (@allLines) {
      chomp;
      if (-f $_) {
        $filelist{$_}="";
      } else {
        print "  WARNING: File <$_> doesn't exist (maybe a broken link?)\n";
      }
    }
  }
} # for ($k)



if ($onlyPrintFileList) {
  for  (keys %filelist) {print "$_\n";}
  exit 0;
}



(keys %filelist!=0) || die "  ERROR: No source files found from the specified input. Terminating";






#---------------------------------------------------------------------
#                 Global data structures:


# Map of the 'mangled' file names (as they will be created in the
# destination directory to the file full paths:
# The KEY is the mangled file name (without the ".html" extension). So
# it will begin with "__dupXX__." if the file has a duplicate name.
# The VALUE is the full original path of the file.
my %fullpath;



# Map of the 'mangled' file names (as they will be created in the
# destination directory) to original file names:
# The KEY is the mangled file name.
# The VALUE is the original name of the file.
#
# THIS IS REALLY REDUNDANT WITH THE PREVIOUS ONE (THAT ALREADY CONTAINS
# THE FULL PATH AND SO ALSO THE FILE NAME)
#
my %origName;



# These are valid during the phase when we scan all the source files
# to create the HTML files ...

# ... these two indicate the file name (of the source
# file) and the line number of the line that we are currently scanning

my ($current_file_name,$current_line_num);


# ... this says if we have found a tag
my $found_a_tag;

# ... this is where we accumulate the line to write in the HTML file
my $html_line;


#---------------------------------------------------------------------






#---------------------------------------------------------------------
#                 Global statistic variables:

my $num_files;

my $num_dup_files; # number of times we found files with the same name

my $total_source_bytes;   # how many bytes in all the source files
  
my $total_html_bytes;     # how many bytes in all the HTML files


my $num_tags;


my $num_dup_tags;  # number of times we found a duplicate definition
                   # for a tag

#---------------------------------------------------------------------




#############  COPY ALL FILES ###############
# All source files are copied to destination directory and the 
# %fullpath table is populated.

print "Copying files in destination directory...\n";


# Create in '@list' a sorted list of strings from the list of filenames.
# Each element of @list contains: the base name of the file (without path) plus
# the fullpath as it was in the %filelist hash (the two separated by spaces)
# FIXIT: MUST BE MODIFIED TO ALLOW FILES WITH @ IN THE NAME IF CLEARCASE NOT USED
my @list;
for  (keys %filelist) {
  /[^@]*/;      #longest sequence that doesn't contain @ (remove clearcase ext path)
  my $path_no_ccase = $&;
  $path_no_ccase =~ /[^\/\\]*$/; # longest sequence at the end that doesn't contain a / or \ (basename)

  # Add an element to @list
  my $listElem=\@{ $list[@list] };
  ${ $listElem } [0]= $&;   # base name of the file
  ${ $listElem } [1]= $_;       # full original path
}

undef %filelist;

@list=sort { ${$a}[0] cmp ${$b}[0] } @list;




my %all_names;  # used to see which filenames we are using.

# let's scan for duplicate filenames and create flat list


# create list of all files for ctags
open NAMELIST,">$dstDir/$namelist" || die "  ERROR: Cannot open $namelist. Terminating";

$num_files=0;
foreach (@list) {
  my ($name,$fullpath)= @{ $_ };

  if (-f $fullpath) {

    # Here we generate the name with which the file will be copied
    # in the destination directory ('mangled' name). It is based on
    # the original name with a couple of modifications

    my $orig_name =  $name;


    # First we replace spaces with underscores

    $name =~ s/ /_/;

    
    # Now,if there is a name clash we prepend "__dupXX__." to the name

    if (exists($all_names{$name})) {


      my $number=1;
      while ($all_names{$name}) {
        $name = "__dup".$number."__.".$orig_name;
        $number++;
      }

      $num_dup_files++;
    }

    $all_names{$name}=1; # value doesn't matter


    $fullpath{$name}=$fullpath;
    $origName{$name}=$orig_name;


    if (!copy($fullpath,"$dstDir/$name")) {
      print "  WARNING: Error in copying <$fullpath> ($ERRNO)\n";
    } else {
      print NAMELIST "$name\n";
    }

    $num_files++;
  } else {
    print "  WARNING: File <$fullpath> doesn't exist\n";
  }
} # foreach (@list)
close NAMELIST;

undef @list;
undef %all_names;


chdir $dstDir || die "  ERROR: cannot change to directory $dstDir ($ERRNO). Terminating";



#############  USE ctags TO GENERATE THE TAG FILE ###############

print "Generating ctags...\n";




if (-f $tagfile) {
  unlink $tagfile || die "  ERROR: Cannot remove old <$tagfile> ($ERRNO). Terminating ";
}

# The "--c-kinds" option tells to tag function prototypes and extern variable decl
# as well but NOT to tag structure fields.
system "$ctags_executable --c-kinds=+p+x-m -f $tagfile -L $namelist --excmd=number";
unlink $namelist;






#############  READ THE TAGS IN %tagInfo HASH IN MEMORY ###############



print "Reading tags table...\n";

open TAGFILE,$tagfile  || die "  ERROR: cannot open $tagfile ($ERRNO). Terminating";

$num_tags=0;
while (<TAGFILE>) {

  # The first few entries begin with the string "!_TAG_" and they are not
  # relevant. We skip them.
  if (!/^!_TAG_/) {
    my ($tagname,$filename,$lineno,$tagType) = split;

    # remove last two chars and convert to int
    $lineno  =int(substr($lineno,0,length($lineno)-2));


    my $thisDefinition=sprintf("$filename#%d#$tagType",$lineno);


    $num_dup_tags++ if (exists($tagInfo{$tagname}));



    # With this we say that ${$tagInfo{$tagname}} is an array and we
    # put a reference to it into the local $tagInfo
    # Note that this is the place where we make ${$tagInfo{$tagname}
    # spring into existence (for the first definition that we find)
    my $tagInfo=\@{ $tagInfo{$tagname} };

    # (Perl reference to) the array with the previous definitions
    my $definitions=\@{ ${ $tagInfo }[0] }; 

    # Add currently found definition to the array
    ${$definitions}[@{$definitions}] = $thisDefinition;


    # Put the tag ID into tagInfo. If a tag has multiple definitions
    # this will be overwritten for each definition, but it doesn't
    # matter as the tagId needs only be unique.
    ${ $tagInfo }[2]=$num_tags;


    $num_tags++;
  }
}
close TAGFILE;


# Now scan the hash table again to see if we can remove
# redundant tag definitions.
while ( my ($tagname, $tagInfo) = each %tagInfo) {

  # (Perl reference to) the array with the definitions for this tag
  my $definitions=\@{ ${ $tagInfo }[0] }; 

  my $numTagDef=@{$definitions}; # how many tag definitions

  # Something to do only if there is more than one tag definition
  if ($numTagDef>1) {

    my $replaceDef="";
    my $replaceType="";
    # count how many definitons of each type
    my %count;

    for (@{$definitions}) {
      my ($filename,$line_no,$tagType)= split /#/;

      $count{$tagType}++;

      if ($tagType eq "f" || $tagType eq "v" || $tagType eq "s" || $tagType eq "u" || $tagType eq "g") {
        # if there was already a "replace" definition, then we abort
        if ($replaceDef ne "" ) {
          $replaceDef="";
          last;
        }
        $replaceDef =$_;
        $replaceType=$tagType;
      }
    } # for (@{$definitions})

    # Now let's check if what we found is really ok.
    if ($replaceDef) {
      if ($replaceType eq "f") {

        # For a function definition, all the others must be prototypes
        $replaceDef="" if ($count{"p"} != $numTagDef-1);

      } elsif ($replaceType eq "v") {

        # For variable definiton, all the others must be 'extern' declaration
        $replaceDef="" if ($count{"x"} != $numTagDef-1);

      } elsif ( ($replaceType eq "s") || ($replaceType eq "u") || ($replaceType eq "g")  ){

        # For structures, union, enum, the only 1 other definiton must be a typedef
        $replaceDef="" if ( ($numTagDef !=2) || ($count{"t"}!=1) );
      }
    }


    # We have decided that we have to replace the multiple definitons
    # with a single one.
    if ($replaceDef ne "") {
      my @newDefs = ($replaceDef);

      my $realTagInfo=\@{ $tagInfo{$tagname} };
      ${ $realTagInfo }[0]=\@{newDefs}; 
    }

  } # if ($numTagDef>1)

} # while






#############  PROCESS EACH SOURCE FILE ###############


# Will specify if we are scanning a line while we are inside a comment.
# Is really relevant only for multiline comment. It must be a global
# variable because we scan one line at a time.
my $inside_comment;


print "Creating HTML files...\n";


# Loop on all the files

foreach (keys %fullpath) {

  $current_file_name=$_;
  my $html_file=$current_file_name.".html";

  if (!open SOURCEFILE,$current_file_name) {
    print "  WARNING: Cannot open $current_file_name ($ERRNO)\n";
    next;
  }

  if (!open HTMLFILE,">$html_file") {
    print "  WARNING: Cannot open $html_file for writing ($ERRNO)\n";
    close SOURCEFILE;
    next;
  }


  # let's find the extension
  $current_file_name =~ /\.[^\.]*$/; #  a dot followed by any char excluding the dot, at the end of the name.
  my $file_ext=$&;
  my $lang=$map_ext_to_lang{$file_ext};

  print "  WARNING: Extension of file <$current_file_name> not recognized\n" if (!$lang);


  ##### PRINT THE BEGINNING OF THE HTML FILE ####
  print HTMLFILE << "ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE>$current_file_name</TITLE>
</HEAD><BODY LINK=$TAG_COLOR VLINK=$TAG_COLOR>
ENDOFHTML

  print HTMLFILE "<B><I>$fullpath{$current_file_name}</I></B><P>\n<PRE>";

  $inside_comment=0;


  # ------- Loop to process one line at a time from source file
  while (<SOURCEFILE>) {

    $current_line_num = $INPUT_LINE_NUMBER;

    my $lineNoStr=sprintf("%4d",$INPUT_LINE_NUMBER);
    $html_line = "$LINENUM_STYLE_BEGIN$lineNoStr:$LINENUM_STYLE_END";

    chomp;
    
    # Escape reserved HTML characters from the line
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;


    $found_a_tag=0;

    if ($lang eq "asm") {
      scanForTagsAsm($_);
    } elsif ($lang eq "perl") {
      scanForTagsPerl($_);
    } else {
      scanForTagsC($_);
    }


    # Add a target anchor to this line if a tag has been found
    $html_line = "<A NAME=\"L$INPUT_LINE_NUMBER\"></A>$html_line" if $found_a_tag;

    print HTMLFILE "$html_line\n";

  } # while (<SOURCEFILE>)


  # we print a few newlines at the end (before closing the <PRE> HTML tag)
  # to facilitate jumping to tags at the end of the file.
  print HTMLFILE "\n" x 50;

  ##### PRINT THE END OF THE HTML FILE ####
  print HTMLFILE "</PRE></BODY></HTML>";


  close HTMLFILE;
  close SOURCEFILE;


  # how many bytes was this file?
  my $fileinfo = stat($current_file_name);
  $total_source_bytes += $fileinfo->size;
  

  # how many bytes is the generated file?
  $fileinfo = stat($html_file);
  $total_html_bytes += $fileinfo->size;

} # foreach (keys %fullpath)




########## remove all temporary files ###############
print "Removing temporary files...\n";
foreach (sort(keys(%fullpath))) { # get all the filenames
  unlink $_;
}
unlink $tagfile;




createAlhpabeticalIndices();



createOtherHTMLPages();



printf("%d files processed (%d Kbytes in source files; %d Kbytes in HTML files)\n",
       $num_files,$total_source_bytes/1024,$total_html_bytes/1024);

print "$num_dup_files duplicate file names found\n" if ($num_dup_files);

print "$num_tags tags found\n";

print "$num_dup_tags duplicate tag names found\n" if ($num_dup_tags);


my $total_time_sec=time()-$start_time;

my $t_hour=$total_time_sec/3600;
my $t_min =($total_time_sec%3600)/60;
my $t_sec =$total_time_sec%60;

printf("Total time: %dh %dm %ds\n",$t_hour,$t_min,$t_sec);


if ($num_tags==0) {
print << "ENDOFWARNING";

  WARNING: No tags were found. Possible causes:
    1) wrong input files specified
    2) "ctags" utility not installed.
    3) "ctags" utility is not "Exuberant Ctags"

ENDOFWARNING
}



###########################################################################
#
# Given a file name returns its name and the number of the duplicate as:
# (filename,number). "number" will be 1, 2, 3 etc for duplicates.
# 
#
#   alfa.c           ==> (alfa.c,0)
#   __dup2__.alfa.c  ==> (alfa.c,2)
#
#
###########################################################################
sub resolveDupFileName($)
{
  if ($_[0] =~ /__dup[0-9]*__./) {
    return ($origName{$_[0]},int(substr($_[0],5,1)));
  } 
  return ($_[0],0);
}




###########################################################################
#
# Takes as input:
# 1) A string
# 2) a boolean.
#
# If the boolean  is 0, the string must be printed as it is in the output
# HTML file. If it is 1, the string might be a tag and we must verify
# if it is indeed one and then print whatever is needed on HTMLFILE
#
###########################################################################
sub printStringToOutput($$)
{
  my ($string,$might_be_a_tag) = @_;

  if ($might_be_a_tag) {

    # To see if it is a tag we check if it is in the %tagInfo table

    if (exists($tagInfo{$string})) {

      # The string is indeed a tag
      $found_a_tag=1;


      # $tagInfo{$tagname} is an array. we put a reference to it into
      # the local $tagInfo
      my $tagInfo=\@{ $tagInfo{$string} };


      # (Perl reference to) the array with the definitions
      my $definitions=\@{ ${$tagInfo}[0] };


      my $tag_id=${$tagInfo}[2];


      my $current_pos = sprintf("$current_file_name#%d",$current_line_num);


      # In which index file should it go? Get the first letter to find out
      my $initial_letter=uc(substr($string,0,1));
      $initial_letter=uc(substr($string,1,1)) if ($initial_letter eq "~");

      my $index_file_name="index-$initial_letter.html";


      #  ---- let's verify if what we have now is a definition or a reference to the tag

      my $is_a_definition=0;
      foreach (@{ $definitions }) {

        # Check if this definition begins with $current_pos
        # (don't use regular expressions as the file might contain
        # improper chars (like "++")
        if (substr($_,0,length($current_pos)) eq $current_pos) {
          # This is (one of the places) where the tag is defined

          $html_line .= "<A HREF=\"$index_file_name#T$tag_id\" TARGET=\"c2html_index\"><B>$string</B></A>";

          $is_a_definition=1;
          last;
        }

      } # foreach (@{ $definitions })


      if (!$is_a_definition) {

        # This is a place where the tag is just used (referenced).
        # We accumulate this reference in the appropriate global table


        # ${$tagInfo}[1] is a reference to an array. We put the reference
        # into the local $tagUsages
        my $tagUsages=\@{ ${$tagInfo}[1] };


        # Add current to the array
        ${$tagUsages}[@{$tagUsages}] = $current_pos;


        # Depending if it has a single or multiple definition, we
        # link it differently:

        if (@{ $definitions }==1)  {
          # Has a single definition: we make it point to the first and only definition.
          my ($file_name,$line_no)= split /#/,${ $definitions }[0];

          $html_line .= "<A HREF=\"$file_name.html#L$line_no\" TARGET=\"c2html_source\">$string</A>";
        } else {
          # Has multiple definitions: we make it point to the index file (in the 'index' frame).
          $html_line .= "<A HREF=\"$index_file_name#T$tag_id\" TARGET=\"c2html_index\">$string</A>";
        }

      } # if (!is_a_definition)

    } else {

      # It wasn't in the %tagInfo table (it wasn't a tag)

      $html_line .= $string;
    }
    
  } else {

    # The second parameter told us that we it wasn't a tag

    $html_line .= $string;
  }
} # printStringToOutput



###########################################################################
#
#
###########################################################################
sub createAlhpabeticalIndices()
{
  print "Creating indices...\n";


  # Get all the tags (and sort them).
  # Sort in alphabetical order, not in "uppercase-first" order
  my @tag=sort  { lc($a) cmp lc($b) }  (keys(%tagInfo));


  for my $letter ('_','A'..'Z') {

    my $file_name="index-$letter.html";
    open HTMLFILE,">$file_name" || die "  WARNING: Cannot create <$file_name> ($ERRNO). Terminating";
    print HTMLFILE <<"ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE></TITLE></HEAD><BODY LINK=$TAG_COLOR VLINK=$TAG_COLOR>
<B>Index of tag usage $letter</B>
<PRE>
ENDOFHTML


    my $letter_lower=lc($letter);

    my $n_tags_found=0;

    foreach (@tag) {
      if (/^($letter|$letter_lower)/) {

        # The tag must be included in the current index file

        my $tagname = $_;

        # $tagInfo{$tagname} is an array. we put a reference to it into
        # the local $tagInfo
        my $tagInfo=\@{ $tagInfo{$tagname} };


        my $tag_id=${$tagInfo}[2];


        # (Perl reference to) the array with the definitions
        my $definitions = \@{ ${$tagInfo}[0] };


        # We print different things depending if the tag has a single or multiple definition
        if (@{ $definitions }==1) {
          my ($file_name,$line_no)= split /#/,${ $definitions }[0];

          print HTMLFILE "<A NAME=\"T$tag_id\"></A><A HREF=\"$file_name.html#L$line_no\" TARGET=\"c2html_source\"><B>$tagname</B></A>";
        } else {
          print HTMLFILE "<A NAME=\"T$tag_id\">$TAG_STYLE_BEGIN<B><I>$tagname</I></B>$TAG_STYLE_END</A> <I>multiply defined at</I>:\n";


          sortPositionArray($definitions);

          foreach (@{ $definitions }) {

            my ($file_name,$line_no)= split /#/;

            # We eliminate the "__dupXX__." string if it is a duplicate file name
            my ($basename,$dup_number)=resolveDupFileName($file_name);
            my $dup_string=($dup_number>0)?  " <I>[$dup_number]</I>"  : "";

            print HTMLFILE " <A HREF=\"$file_name.html#L$line_no\" TARGET=\"c2html_source\"><B>$basename$dup_string : $line_no</B></A>\n";

          }
        }


        # ${$tagInfo}[1] is a reference to an array. We put the reference
        # into the local $tagUsages
        my $tagUsages=\@{ ${$tagInfo}[1] };

        if (@{$tagUsages}!=0) {
          print HTMLFILE " referenced in:\n";


          sortPositionArray($tagUsages);

          for (@{$tagUsages}) {

            my ($file_name,$line_no)= split /#/;

            # We eliminate the "__dupXX__." string if it is a duplicate file name
            my ($basename,$dup_number)=resolveDupFileName($file_name);
            my $dup_string=($dup_number>0)?  " <I>[$dup_number]</I>"  : "";

            print HTMLFILE "  <A HREF=\"$file_name.html#L$line_no\" TARGET=\"c2html_source\">$basename$dup_string : $line_no</A>\n";
          }
          print HTMLFILE "\n";
        } else {
          print HTMLFILE " is never referenced.\n\n";
        }

        $n_tags_found++;


        # If there is a C++ destructor, we treat it specially: we list it just
        # after the constructor.

        $tagname ="~$tagname";
        if (exists($tagInfo{$tagname})) {
          my $tagInfo=\@{ $tagInfo{$tagname} };
          my $tag_id=${$tagInfo}[2];
          my $definitions = \@{ ${$tagInfo}[0] };

          my ($file_name,$line_no)= split /#/,${ $definitions }[0];

          print HTMLFILE "<A NAME=\"T$tag_id\"></A><A HREF=\"$file_name.html#L$line_no\" TARGET=\"c2html_source\"><B>$tagname</B></A>\n\n";
        }


      } # if (/^($letter|$letter_lower)/)

    } # foreach (@tag)

    print HTMLFILE "No tags beginning with $letter\n" if ($n_tags_found==0);

    print HTMLFILE '</PRE></BODY></HTML>';
    close HTMLFILE;

    # Accumulates the number of bytes of the file
    my $fileinfo = stat($file_name);
    $total_html_bytes += $fileinfo->size;

  } # for my $letter

} # createAlhpabeticalIndices


###########################################################################
#
# Given a reference to an array that contains 'position' strings, like:
#
#   filename.cpp#123
#   another.h#11
#    ...
#
# sorts the array based on filename and line number
#
###########################################################################
sub sortPositionArray()
{
  @{$_[0]} = sort {
    my ($f1,$l1)= split /#/,$a; my $fo1=$origName{$f1};
    my ($f2,$l2)= split /#/,$b; my $fo2=$origName{$f2};

    # first compare the original filenames (case insensitive)
    my $result = lc($fo1) cmp lc($fo2);
    return $result if ($result);

    # then compare the mangled filenames (case insensitive), in case
    # the files are different but with the same name.
    $result    = lc($f1) cmp lc($f2);
    return $result if ($result);

    # as last thing compare the line numbers
    return $l1 <=> $l2;          # if names equal, compare line numbers
  }  @{$_[0]};
} # sortPositionArray


###########################################################################
#
# Generates the other pages: main page, the indices etc.
#
###########################################################################
sub createOtherHTMLPages()
{

print "Creating top level HTML pages\n";

#---------------------------------------------------------
# Top level page. We do three identical copies of this named:
#
#   src2html-frames.html: for compatibility with older
#               versions
#   index.html: so that HTTP servers can serve it
#               when only the directory is specified
#   ___START_PAGE.html: so that it is at the top of the list
#               of a GUI file manager
#---------------------------------------------------------
open HTMLFILE,">src2html-frames.html" || die "  WARNING: Cannot create <src2html-frames.html> ($ERRNO). Terminating";
print HTMLFILE <<"ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN"
   "http://www.w3.org/TR/REC-html40/frameset.dtd">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE>$page_title</TITLE>
</HEAD>
  <FRAMESET rows="7,93">
    <FRAME SRC="top-cmds-page.html">
    <FRAME SRC="bottom-frames.html">
  </FRAMESET>
</HTML>
ENDOFHTML
close HTMLFILE;
copy("src2html-frames.html","index.html");
copy("src2html-frames.html","___START_PAGE.html");

# Accumulates the number of bytes of the file
my $fileinfo = stat("index.html");
$total_html_bytes += 3*$fileinfo->size;



#---------------------------------------------------------
#---------------------------------------------------------
open HTMLFILE,">bottom-frames.html" || die "  WARNING: Cannot create <bottom-frames.html> ($ERRNO). Terminating";
print HTMLFILE <<"ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN"
   "http://www.w3.org/TR/REC-html40/frameset.dtd">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE>Source code viewer</TITLE>
</HEAD>
  <FRAMESET COLS="30,70">
    <FRAME SRC="index-A.html" name="c2html_index"> 
    <FRAME SRC="files.html"   name="c2html_source">
  </FRAMESET>
</HTML>
ENDOFHTML
close HTMLFILE;

# Accumulates the number of bytes of the file
$fileinfo = stat("bottom-frames.html");
$total_html_bytes += $fileinfo->size;



#---------------------------------------------------------
# List of all source files
#---------------------------------------------------------
open HTMLFILE,">files.html" || die "  WARNING: Cannot create <files.html> ($ERRNO). Terminating";
print HTMLFILE <<"ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE>File list</TITLE>
</HEAD><BODY>
ENDOFHTML



# Put in a list all the filenames.
my @all_names_flat;
foreach (keys(%fullpath)) {
  my ($real_name,$dup_number)=resolveDupFileName($_);


  my $element=\@{ $all_names_flat[@all_names_flat] };
  ${ $element }[0]=$real_name;
  ${ $element }[1]=$dup_number;
  ${ $element }[2]=$_;    # the mangled name
}

# Sort (in alphabetical order, not in "uppercase-first" order)
@all_names_flat = sort {

    my $ result = lc( ${$a}[0] ) cmp lc( ${$b}[0] );
    return $result if ($result);

    return ${$a}[1] <=> ${$b}[1]
  }  (@all_names_flat);



# now we can print them
my $numFiles=@all_names_flat;
print HTMLFILE "<FONT COLOR=\"808080\">$numFiles files:</FONT><BR>";

foreach (@all_names_flat) { 

  # "filename" will contain the name as copied in the directory
  # (with the "__dupXX__." prefix if duplicated) while "real_name"
  # is the original name

  my ($real_name,$dup_number,$filename) = @{ $_ };

  my $dup_string=($dup_number>0)?  " <I>[$dup_number]</I>"  : "";
  print HTMLFILE "<TT><A HREF=\"$filename.html\">$real_name$dup_string</A>    <FONT SIZE=-1 COLOR=\"808080\">$fullpath{$filename}</FONT></TT><BR>";
}

undef @all_names_flat;

print HTMLFILE '</BODY></HTML>';

close HTMLFILE;

# Accumulates the number of bytes of the file
$fileinfo = stat("files.html");
$total_html_bytes += $fileinfo->size;


#---------------------------------------------------------
#
#---------------------------------------------------------
open HTMLFILE,">top-cmds-page.html" || die "  WARNING: Cannot create <top-cmds-page.html> ($ERRNO). Terminating";
print HTMLFILE << "ENDOFHTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<TITLE></TITLE>
</HEAD>
<BODY>

<TABLE WIDTH="100%">
<TR>
<TD ALIGN=LEFT WIDTH="60%">
<FONT SIZE=-1>
<A HREF="index-_.html" target="c2html_index">_</A>
<A HREF="index-A.html" target="c2html_index">A</A>
<A HREF="index-B.html" target="c2html_index">B</A>
<A HREF="index-C.html" target="c2html_index">C</A>
<A HREF="index-D.html" target="c2html_index">D</A>
<A HREF="index-E.html" target="c2html_index">E</A>
<A HREF="index-F.html" target="c2html_index">F</A>
<A HREF="index-G.html" target="c2html_index">G</A>
<A HREF="index-H.html" target="c2html_index">H</A>
<A HREF="index-I.html" target="c2html_index">I</A>
<A HREF="index-J.html" target="c2html_index">J</A>
<A HREF="index-K.html" target="c2html_index">K</A>
<A HREF="index-L.html" target="c2html_index">L</A>
<A HREF="index-M.html" target="c2html_index">M</A>
<A HREF="index-N.html" target="c2html_index">N</A>
<A HREF="index-O.html" target="c2html_index">O</A>
<A HREF="index-P.html" target="c2html_index">P</A>
<A HREF="index-Q.html" target="c2html_index">Q</A>
<A HREF="index-R.html" target="c2html_index">R</A>
<A HREF="index-S.html" target="c2html_index">S</A>
<A HREF="index-T.html" target="c2html_index">T</A>
<A HREF="index-U.html" target="c2html_index">U</A>
<A HREF="index-V.html" target="c2html_index">V</A>
<A HREF="index-W.html" target="c2html_index">W</A>
<A HREF="index-X.html" target="c2html_index">X</A>
<A HREF="index-Y.html" target="c2html_index">Y</A>
<A HREF="index-Z.html" target="c2html_index">Z</A>
</FONT>
</TD>

<TD ALIGN=RIGHT WIDTH="20%">
<A HREF="files.html" target="c2html_source">Show list of all files</A>
</TD>

<TD ALIGN=RIGHT WIDTH="20%">
<FONT SIZE="-2">SRC2HTML v. $currentVersion</FONT>
</TD>

</TR></TABLE>

</BODY>
</HTML>
ENDOFHTML
close HTMLFILE;

# Accumulates the number of bytes of the file
$fileinfo = stat("top-cmds-page.html");
$total_html_bytes += $fileinfo->size;


} # createOtherHTMLPages

















###########################################################################
###########################################################################
#
# Finding tag references (uses): C language
#
# Scans a string for tags. Calls repeatedly printStringToOutput() to
# print out tags and non-tags strings
#
# Note that, when this is called, non HTML-friendly chars have been changed
# to their HTML encoding:
#    "<"  =>  "&lt;"
#    "<"  =>  "&lt;"
#    "&"  =>  "&amp;"
#
###########################################################################
###########################################################################
sub scanForTagsC($)
{

  #--------------------------------------------------------------------------
  #
  #--------------------------------------------------------------------------
  sub scanForTagsCNoComments($)
  {
    my $line = $_[0];


    while ($line) {


      # search for longest string that does not contain double quotes (\x22)
      last if ( $line !~ /"[^\x22]*"/ );

      scanForTagsCNoStrings($`);
      printStringToOutput $&,0;

      $line= $';

    }

    scanForTagsCNoStrings($line);
  } # scanForTagsCNoComment

  #--------------------------------------------------------------------------
  #
  #--------------------------------------------------------------------------
  sub scanForTagsCNoStrings($)
  {
    my $line = $_[0];

    while ($line) {

      # Search for longest identifier (begins with "_" or "~" or letter
      # and then contains "_", letters or numbers
      last if (  $line !~ /(_|~|[a-zA-Z])(_|[a-zA-Z]|[0-9])*/ );


      printStringToOutput $`,0;
    

      # If the string is "&lt;", "&lt;" or "&lt;", it must be one the HTML
      # code for a character, not a tag named "lt", "gt" or "amp"
      if ( ((substr($`,-1,1) eq "&") && (substr($',0,1) eq ";") ) &&
           (($& eq "lt") || ($& eq "gt")  || ($& eq "amp") ) )
      {
        printStringToOutput $&,0;
      } else {
        printStringToOutput $&,1;
      }


      $line= $',0;
    }

    printStringToOutput $line,0;
  } # scanForTagsCNoStrings


  # -------------------------------------------------------
  my $line = $_[0];


  # We loop inside here, breaking the line into comment and non comment
  # section. $line is reduced every time to the remaining part
  while ($line) {

    if (!$inside_comment) {



      #  ------------ is it an 'include' line ? -------------
      if ($line =~ /^[ \t]*#[ \t]*include/) {

        # We match everything on the line up to (including) the quotes
        # or "<" that marks the beginning of the filename
        $line      =~ /[^"&]*("|&lt;)/;
        printStringToOutput($&,0);    


        # Now, from what was left (POSTMATCH), we match the filename
        # up to (excluding) the closing quotes or ">"
        $' =~ /[^"&]*/;

        my $filename=$&;

        my $leftover=$';


        # If the name contains a path, we remove the path
        my $dir="";
        if ($filename =~ /.*\//) {  # this matches everything up to the last slash
          $dir=$&;
          $filename=$';
        }
  

        if (-f $filename){
          printStringToOutput("$dir<A HREF=\"$filename.html\">$filename</A>",0);
        } else {
          printStringToOutput("$dir$filename",0);
          print "  WARNING: Cannot find $dir$filename included by $current_file_name\n" if ($warnIncludesNotFound);
        }

        # Nothing else on an include line
        printStringToOutput($leftover,0);    
        return;
      } # ----------- it was an "include" line ----------


      # -----------------------------------------------------------
      # Search C++ style comment; if found, scan the part up to the
      # start of comment and the print the comment.
      # FIXIT: THIS DOESN'T WORK PROPERLY IF THERE IS A
      # /* ... */ COMMENT BEFORE THE C++ STYLE COMMENT IN THE LINE
      if ( $line =~ /\/\// ) {
        scanForTagsCNoComments($`);
        printStringToOutput "$COMMENT_STYLE_BEGIN$&$'$COMMENT_STYLE_END",0;
        $line="";
        last;
      }


      # Search beginning of comment...
      last if ( $line !~ /\/\*/ );

      # ...found
      $inside_comment=1;
      scanForTagsCNoComments($`);

      printStringToOutput "$COMMENT_STYLE_BEGIN$&",0;

      $line= $';

    } # if (!$inside_comment)


    # Search end of comment...
    last if ( $line !~ /\*\// );

    # ...found
    $inside_comment=0;
    printStringToOutput($`,0);
    printStringToOutput("$&$COMMENT_STYLE_END",0);

    $line= $';

  } # while ($line)

  if ($inside_comment) {
    printStringToOutput($line,0);
  } else {
    scanForTagsCNoComments($line);
  }
} # scanForTagsC








###########################################################################
###########################################################################
#
# Finding tag references (uses): ASM language
#
# Scans a string for tags. Calls repeatedly printStringToOutput() to
# print out tags and non-tags strings
#
# Note that, when this is called, non HTML-friendly chars have been changed
# to their HTML encoding:
#    "<"  =>  "&lt;"
#    "<"  =>  "&lt;"
#    "&"  =>  "&amp;"
#
###########################################################################
###########################################################################
sub scanForTagsAsm($)
{
  my $line = $_[0];



  # search for a comment (hash or semicolon)

  my $comment_part;
  if ($line =~ /[#;]/) {
    chomp;
    $comment_part="$COMMENT_STYLE_BEGIN$&$'$COMMENT_STYLE_END\n";

    $line = $`;
  }

  while ($line) {

    # Search for longest identifier (begins with "_" or letter
    # and then contains "_", letters or numbers
    last if (  $line !~ /(_|[a-zA-Z])(_|[a-zA-Z]|[0-9])*/ );

    printStringToOutput $`,0;
    printStringToOutput $&,1;

    $line= $',0;
  }

  printStringToOutput $line,0;

  printStringToOutput $comment_part,0;

} # scanForTagsAsm






###########################################################################
###########################################################################
#
# Finding tag references (uses): Perl language
#
# Scans a string for tags. Calls repeatedly printStringToOutput() to
# print out tags and non-tags strings
#
# Note that, when this is called, non HTML-friendly chars have been changed
# to their HTML encoding:
#    "<"  =>  "&lt;"
#    "<"  =>  "&lt;"
#    "&"  =>  "&amp;"
#
###########################################################################
###########################################################################
sub scanForTagsPerl($)
{
  my $line = $_[0];



  # search for a comment (hash)

  my $comment_part;
  if ($line =~ /[#]/) {
    chomp;
    $comment_part="$COMMENT_STYLE_BEGIN$&$'$COMMENT_STYLE_END";

    $line = $`;
  }

  while ($line) {

    # Search for longest identifier (begins with "_" or letter
    # and then contains "_", letters or numbers
    last if (  $line !~ /(_|[a-zA-Z])(_|[a-zA-Z]|[0-9])*/ );

    printStringToOutput $`,0;
    printStringToOutput $&,1;

    $line= $',0;
  }

  printStringToOutput $line,0;

  printStringToOutput $comment_part,0;

} # scanForTagsPerl





#**************************************************************************
#**************************************************************************
#
# Some general utility functions
#
#**************************************************************************
#**************************************************************************




###########################################################################
#
# Given the output of a Clearcase catcr command, this will flatten it
# to a simple list of files.
#
# First arg is the name of the (text) file containing the catcr output
#
# second arg is name of the file where to put the flat list.
# 
###########################################################################
sub flattenCatCr($$)
{
  my ($inputfile,$outputfile) = @_;

  my (@list1,@list2);

  open INPUTFILE,$inputfile || die "  ERROR: Cannot open <$inputfile> ($ERRNO). Terminating";

  # Accumulate all the filenames in 'list1'
  while (<INPUTFILE>) {
    chomp;
    ONE_LINE: for (split) {

      my ($extension,$path,$full_filepath,$extended_part);

      $full_filepath= $_;

      # Extract a possible candidate path (the part before the @@)
      # and the clearcase extended part
      ($path,$extended_part)= ($1,$2) if (/([^@]*)@@(.*)/);

      # if the extended_part does not begin with slash or backslash,
      # then this is a derived object, and we drop the extended part
      $full_filepath=$path if ($extended_part !~ /^[\\\/]/);

      $extension = $1 if ($path =~ /(\.[^\.]*)$/);

      if ($full_filepath && $extension) {
        for (keys(%map_ext_to_lang)) {
          if ($extension eq $_) {
            $list1[@list1]= $full_filepath;
            last ONE_LINE;
          }
        }
      } # if ($full_filepath && $extension)
    } # for (split)
  } # while 
  close INPUTFILE;

  # sort (in list2) and remove duplicates (in list1)
  @list2=sort(@list1);
  my $prev = "not equal to $list2[0]";
  @list1 = grep($_ ne $prev && ($prev = $_, 1), @list2);


  # print the filenames and the base filenames
  open OUTPUTFILE,">$outputfile" || die "  ERROR: Cannot create <$outputfile> ($ERRNO). Terminating";
  foreach (@list1) {
    print OUTPUTFILE "$_\n";
  }
  close OUTPUTFILE;

} # flattenCatCr


###########################################################################
#
# like File::Spec->rel2abs (not implemented in perl 5.005_03)
#
###########################################################################
sub findAbsPath($)
{
    my $path = $_[0];

    $path = File::Spec->catdir( cwd(), $path ) if ( ! File::Spec->file_name_is_absolute( $path ) );

    return File::Spec->canonpath( $path ) ;
}


###########################################################################
#
# like File::Spec->splitpath (not implemented in perl 5.005_03)
#
# The Perl code is copied from the perl library iimplementation
#
###########################################################################
sub splitpath($) {
  my ($path) = @_;

  my ($volume,$directory,$file) = ('','','');

  if ($OSNAME eq "MSWin32") {
    $path =~ 
        m@^ ( (?: [a-zA-Z]: |
                  (?:\\\\\\\\|//)[^\\\\/]+[\\\\/][^\\\\/]+
              )?
            )
            ( (?:.*[\\\\/](?:\.\.?$)?)? )
            (.*)
         @x;
    $volume    = $1;
    $directory = $2;
    $file      = $3;
  } else {
    $path =~ m|^ ( (?: .* / (?: \.\.?\Z(?!\n) )? )? ) ([^/]*) |xs;
    $directory = $1;
    $file      = $2;
  }

  return ($volume,$directory,$file);
}



###########################################################################
#
# Scans a directory (possibly recursively), returning a list with the
# names of all files contained in the directory.
#
# Arguments are:
#
# 1) A string specifying a directory name
#
# 2) A boolean (0/1) specifying if recursive scanning is desired.
#
# Note that the returned list contains only the files, not the subdir
# names.
#
###########################################################################
sub scanDirectory($$)
{
  my @filelist;

  my $IsRecursive=$_[1];

  # Involved declaration of a local subroutine, to allow for
  # correct scoping of the local variables of 'scanDirectory'
  my $scanDirectoryRecursive;
  $scanDirectoryRecursive = sub {
    my $dirName=$_[0];

    if (!opendir(DIRECTORY_TO_SCAN,$dirName)) {
      printf("  WARNING: cannot open $dirName ($ERRNO)\n");
    } else {
      my @dirlist = readdir(DIRECTORY_TO_SCAN);
      closedir(DIRECTORY_TO_SCAN);
      for (@dirlist) {
        if ( ($_ ne ".") && ($_ ne "..") ) {
          my $dirEntry="$dirName/$_";
          if (-d $dirEntry ) {
            &$scanDirectoryRecursive($dirEntry) if ($IsRecursive);
          } else {
            $filelist[@filelist] = $dirEntry;
          }
        } # if
      } # for
    }
  }; # scanDirectoryRecursive

  &$scanDirectoryRecursive($_[0]);

  return @filelist;
} # scanDirectory




###########################################################################
#
###########################################################################
sub usageAndTerminate($) {

print $_[0];

print << "ENDOFUSAGE";

src2html: converts source code to HTML.

version $currentVersion

requires perl version 5.005_03 or successive.


BASIC USAGE (to specify where to find the source files):

 src2html.pl -c <Clearcase DO (Derived Object)>  <destination directory>
     or
 src2html.pl -C <text file output from ct catcr>  <destination directory>
     or
 src2html.pl -l <text file with list of source files>  <destination directory>
     or
 src2html.pl -d <single directory of source files>  <destination directory>
     or
 src2html.pl -D <base directory of source files>  <destination directory>
     or
 src2html.pl -F <single source file name>  <destination directory>

You can specify more than one option, possibly of different types.
For example:

  src2html.pl -c obj1.out -C app.catcr.txt -F includeAll.h dev/html_sources

The difference between "-d" and "-D" is that with "-D" the specified
directory is scanned recursively.

The destination directory will be created if it doesn't exist.


OTHER OPTIONS:

-f : no HTML generation is performed but the list of all source files that
     would be processed is printed on stdout.

-i : warn for C #include files that are #included but are not part of the
     input list.

-t <title> : the specified string <title> is used as title of the main HTML
     page

-v : generate valid HTML. With this option, comments and line numbers will
     be in italic instead of being in grey.



You can specify options in any order, but the destination directory must
always be the last argument.

The "-z" options of the old version is not supported.

Concept & look based on:
  Src2HTML v0.3 : Source code to HTML converter.
  Copyright Ian M. Rae Nov  6 1998

Uses:
  Exuberant Ctags Copyright (C) 1996-2003 Darren Hiebert
  Addresses: <dhiebert\@users.sourceforge.net>, http://ctags.sourceforge.net

ENDOFUSAGE

exit 0;
}
