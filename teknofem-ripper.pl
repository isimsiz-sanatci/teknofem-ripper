#!/usr/bin/perl

=pod

=head1 ISIM

teknofem-ripper.pl - L<http://teknofem.com/> video indirici

=head1 OZET

teknofem-ripper.pl uygulamasini, hic bir arguman olmadan calistirarak
tum siteyi ripleyebilirsiniz. Videolari varsayilan olarak bulundugunuz
dizindeki 'videolar' dizinine ceker.

B<UYARI>: Teknofem arsivi yuzlerce GB video barindirmaktadir. Tum arsivi
cekmek yerine sadece belli kategorideki videolari indirmek isteyebilirsiniz.
Bunun icin yazinin devamindaki I<ORNEKLER> bolumunu okuyunuz.

=head1 ACIKLAMA

Bu uygulamayi B<perl> kurulu herhangi bir sistemde calistirabiliriniz. Windows
icin perl'u L<http://strawberryperl.com/> adresinden edinebilirsiniz.
Strawberry perl, bu uygulamanin calismasi icin gereken tum paketleri icerir.
Strawberry perl kurduktan sonra, sadece I<teknofem-ripper>'e cift tiklayarak
tum videolari indirmeye baslayabilirsiniz.

Eger linux ve benzeri isletim sistemi kullaniyorsaniz;
libwww, JSON ve YAML modullerine ihtiyaciniz var. Debian ve turevi
dagitimlarda C<apt-get install libwww-perl libjson-perl libyaml-perl>
komutuyla gerekli tum paketleri kurabilirsiniz. Diger isletim sistemleri icin,
isletim sisteminizin belgelerine bakarak ilgili paket isimlerini
bulabilirsiniz.

Bu uygulama ayrica I<rtmpdump> kullanarak videolari kaydetmektedir. Linux
isletim sistemi icin paket yoneticisinizden C<rtmpdump> paketini
kurabilirsiniz. Windows isletim sistemi icin, I<rtmpdump>'un ana sayfasindan
L<http://rtmpdump.mplayerhq.hu/> windows icin insa edilmis surumu indirip,
bu uygulamanin calistigi dizine veya isletim sisteminizin varsayilan I<PATH>
dizinlerinden herhangi birine atabilirsiniz.

=head1 ORNEKLER

=over 7

=item B<./teknofem-ripper.pl>

Tum videolari 'videolar' dizinine indirir.

=item B<./teknofem-ripper.pl -P> I<dersler>

Tum videolari belirttiginiz I<dersler> dizinine indirir.

=item B<./teknofem-ripper.pl -G>

Sadece dizin duzenini olusturur, hic bir video indirmez. Olusturdugunuz
duzen ile istediginiz bir kategorideki videolari indirebilirsiniz.

=item B<./teknofem-ripper.pl -d> I<videolar/matematik/temel-kavramlar>

Sadece I<videolar/matematik/temel-kavramlar> kategorisine ait videolari indirir.
Bu dizin daha once bu uygulama tarafindan dizin duzenegi olusturulduktan
sonra kullanilmalidir.

=back

=head1 ARGUMANLER

Uygulama herhangi bir komut satiri argumani girilmeden calistirildiginda,
once kategorileri alir ve video dizinlerini/linklerini olusturur. Ardindan
bu dizinleri kullanarak tum videolari ceker.

Komut satiri parametrelerinin bir listesi asagida verilmistir:

=over 7

=item B<-P, --prefix>[=I<dizin>]

Kategori yapisi icin kullanilacak I<dizin>. Eger bu paramatre girilmezse
varsayilan dizin olarak uygulamanin calistigi dizin icersinde
'videos' kullanilir.

=item B<-G, --generate-layout>

Kategorileri cekerek video dizinlerini ve video linklerini olusturur.

=item B<-S, --download-all-videos>

Daha once olusturulmus indirme dizinlerini kullanarak tum videolari indirir.

=item B<-d, --download>[=I<dizin>]

I<dizin> icersindeki video linklerini kullanarak, sadece o dizin icerisindeki
videolari indirir.

=item B<-r, --rtmpdump>[=I<yol>]

rtmpdump uygulamasinin yolu. Eger uygulama isletim sisteminizin varsayilan
uygulama calistirma dizinlerinden birindeyse (I<PATH>), rtmpdump yolunu
belirlemenize gerek yoktur.

=item B<-v, --verbose>

Uygulama calisirken ayrintili ciktilari gosterir.

=item B<-h, --help>

Uygulamanin kullanimi hakkinda genel bilgi.


=back

=head1 COPYRIGHT

Copyright 2014, Ismini Aciklamak Istemeyen Bir Seyirci

Bu uygulama, Perl'in kendi lisansi altinda degistirip/tekrar
dagitabildiginiz ozgur bir yazilimdir.


=cut

use strict;
use warnings;
use Cwd;
use Encode;
use File::Path qw (make_path);
use File::Find;
use Getopt::Long;
use JSON;
use LWP::UserAgent;
use Pod::Usage;
use YAML qw/LoadFile Dump/;


our $VERSION = '0.01';
my $OPTIONS = {
  PREFIX   => 'videolar',
  DEBUG    => 1,
  CWD      => getcwd (),
  RTMPDUMP => '',
  DO_NOT_DOWNLOAD => ''
};

my $ua;

#####################################################################
# URLs:                                                             #
#                                                                   #
# Kategoriler:                                                      #
# http://www.teknofem.com/api/categories/705?devmenu=1              #
#                                                                   #
# videolar icin iki tane kategori var:                              #
# 705: Fem TV                                                       #
# 7616: Fem Akademi TV                                              #
#                                                                   #
# Icerik:                                                           #
# http://www.teknofem.com/api/fem-tv/content-list/?category_id=8046 #
# category_id tahmin ettigin gibi                                   #
#####################################################################


sub debug {
  return if defined $_[1] && $OPTIONS->{DEBUG} != $_[1];
  print $_[0], "\n";
}

sub generate_filename {
  my ($title, $url, $c) = @_;

  $title = encode ('utf8', $title);

  # turkce karakterler
  my %tr = qw (
    \xc3\x87 c    \xc3\xa7 c    \xc4\xb0 i    \xc4\xb1 i
    \xc4\x9e g    \xc4\x9f g    \xc3\xb6 o    \xc3\x96 o
    \xc5\x9e s    \xc5\x9f s    \xc3\x9c u    \xc3\xbc u
  );

  $title =~ tr/[A-Z]/[a-z]/;
  $title =~ s/$_/$tr{$_}/g for keys %tr;
  $title =~ s/ /-/g;
  $title =~ s/[^-\w\.]//g;
  $title =~ s/\W+/-/g;
  $title =~ s/(^\W|\W$)//g;

  my ($suffix) = $url =~ /\.([\w]{3})$/;

  return "$c-$title.$suffix";
}


sub parse_videos {
  my $content = shift;
  my $path = shift || '.';
  my $videos = [];
  my $c = '01';
  for (@{$content->{data}->{menu}}) {
    my $meta = decode_json ($_->{meta});
    push @{$videos}, [ $meta->{chapter_name},
                       generate_filename ($meta->{chapter_name},
                                          $meta->{video_url},
                                          $c++),
                       $meta->{video_url} ];
  }

  open my $fh, '>', $path . '/videos.yaml' or die $^E;
  binmode $fh, ':utf8';
  print $fh Dump ($videos);
  close $fh;
}



sub make_ua {
  $ua = LWP::UserAgent->new ();
  $ua->agent ('Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 9.0; en-US)');
  $ua->default_header ('Referer' => 'http://www.teknofem.com/');
  $ua->cookie_jar ({});
}


sub get {
  my $url = shift;
  my $response = $ua->get ($url);
  if ($response->is_success) {
    return $response->decoded_content;
  } else {
    die "$url alinirken hata olustu: " . $response->status_line . "\n";
  }
}



sub get_cat {
  my $cat = shift;
  my $parent = shift || '';
  my $dir = $OPTIONS->{PREFIX} . '/' . $parent . $cat->{slug};

  debug ("Dizin olusturuluyor: $dir");
  make_path ($dir);

  if (defined $cat->{data}) {
    $parent .= $cat->{slug} . '/';
    get_cat ($_, $parent) for (@{$cat->{data}});
  }
  
  # TODO: buraya biraz dokumantasyon lazim
  #       ilerde anlamasi zorlasabilir
  else {
    my $content_videos = decode_json (
                            get ('http://www.teknofem.com/api/fem-tv/' .
                                'content-list/?category_id=' . $cat->{id}));
    parse_videos ($content_videos, $dir);
  }
}



sub get_categories_and_links {
  # ana kategori idleri
  # 705: Fem TV
  # 7616: Fem Akademi TV
  my @cids = qw (705 7616);

  for (@cids) {
    my $content = decode_json (
                      get ("http://www.teknofem.com/api/categories" .
                           "/$_?devmenu=1"));
    get_cat ($_) for (@{$content->{data}});
  }
}

sub find_rtmpdump {

  return $OPTIONS->{RTMPDUMP} if $OPTIONS->{RTMPDUMP};

  if ($^O eq 'MSWin32') {

  } else {
    system ('rtmpdump -h > /dev/null 2>&1');
    die "rtmpdump bulunamadi. Paket yöneticiniz ile " .
        "rtmpdump paketini kurunuz\n" if $?;
    return 'rtmpdump';
  }
}


sub make_playpath {
  my ($playpath) = $_[0] =~ /^.*?\/\/.*?\/.*?\/(.*?)$/;
  return $playpath;
}

sub download_video {
  my ($title, $filename, $link) = @_;

  print "$filename indiriliyor\n";

  my @args = (
    find_rtmpdump (),
    '-e',
    '-r' => $link,
    '-y' => make_playpath ($link),
    '-o' => $filename,
    '-W' => 'http://www.teknofem.com/assets/js/flowplayer/' .
            'flowplayer.commercial-3.2.16.swf'
  );

  push @args, '-q' if $OPTIONS->{DEBUG} < 2;

  my $error_count = 0;

  do {
    my $debug_out = 'Calistirilan komut:';
    $debug_out .= " $_" for @args;
    debug ($debug_out, 2);

    return if ($OPTIONS->{DO_NOT_DOWNLOAD});

    system (@args);

    if ($?) {
      if (++$error_count < 10) {
        warn "$filename indirilirken hata olustu 3 saniye sonra " .
             "tekrar deneniyor\n";
        sleep 3;
      } else {
        warn "$filename indirilirken cok fazla hata olustu, " .
             "hata ciktisini inceleyin\n";
        exit 155;
      }
    }
  } while ($?);

}


sub download_all_videos {
  my $path = shift || $OPTIONS->{PREFIX};
  my $wanted = sub {
    return if $_ ne 'videos.yaml';

    my $videos = LoadFile ($_);
    download_video (@{$_}) for (@{$videos});
  };
  find ($wanted, $path);
}


sub main {
  binmode STDOUT, ':utf8';

  my $actions = {
    get_categories_and_links => '',
    download_all_videos      => '',
    download_video           => '',
    help                     => ''
  };

  GetOptions (

    # genel secenekler
    'prefix|P=s' => \$OPTIONS->{PREFIX},
    'verbose|v'  => \$OPTIONS->{DEBUG},
    'verbose-level|V=i'=> \$OPTIONS->{DEBUG},
    'rtmpdump|r' => \$OPTIONS->{RTMPDUMP},
    'do-not-download' => \$OPTIONS->{DO_NOT_DOWNLOAD},

    # islemler
    'generate-layout|G'     => \$actions->{get_categories_and_links},
    'download-all-videos|S' => \$actions->{download_all_videos},
    'download|d=s'          => \$actions->{download_video},
    'help|h'                => \$actions->{help}

  );


  # help
  if ($actions->{help}) {
    pod2usage (-verbose  => 99,
               -sections => [ qw (ISIM ORNEKLER) ]);
  }

  make_ua ();

  # hic arguman girilmediyse
  if (!$actions->{get_categories_and_links} &&
      !$actions->{download_all_videos} &&
      !$actions->{download_video} &&
      !$actions->{help})
  {
    get_categories_and_links ();
    download_all_videos ();
  } elsif ($actions->{get_categories_and_links}) {
    get_categories_and_links ();
  } elsif ($actions->{download_all_videos}) {
    download_all_videos ();
  } elsif ($actions->{download_video}) {
    download_all_videos ($actions->{download_video});
  }

}

&main ();


__END__

