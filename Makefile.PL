
use ExtUtils::MakeMaker;

WriteMakefile (
  NAME         => 'teknofem-ripper',
  VERSION_FROM => 'teknofem-ripper.pl',
  AUTHOR       => 'biri <biri@bir-yer>',
  ABSTRACT     => 'Teknofem indirici',
  EXE_FILES    => [ 'teknofem-ripper.pl' ],
  PREREQ_PM    => {
    'Cwd'            => 0,
    'Encode'         => 0,
    'File::Path'     => 0,
    'File::Find'     => 0,
    'Getopt::Long'   => 0,
    'JSON'           => 0,
    'LWP::UserAgent' => 0,
    'Pod::Usage'     => 0,
    'YAML'           => 0
  }
);
