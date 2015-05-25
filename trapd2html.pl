#!/usr/local/bin/perl
#
# trapd2html.pl
# ---------------------------------------------------------------------
# Analiza en fichero trapd.conf de OpenView NNM.
# El objetivo es documentar un fichero trapd.conf de OVNNM
# sin necesidad de tener que cargar el MIB Browser, etc..
#
# $Version: 1.0$
# I�igo Gonzalez <inigo_[@]_exocert_[.]_com>

# Tomamos de stdin (o del fichero que se nos pase como argumento)
# del contenido del fichero trapd.conf de OV.

# Paso 1: Comprobamos que el fichero comienza con la cadena "VERSION 3":

my $fase;
my $version = <>;
my %category;
my %category_to_num;
my %action;
my %oid;
my %event;
my $evoid;
my $maxcat;

sub obtieneDESC
{

   my $retval;
   my $line;

   $line = <>;
   chop $line;

   while ( $line ne 'EDESC' ) {
      if ( $line ne 'SDESC' ) { $retval .= "$line\n"; }
      $line = <>;
      chop $line;
   }

   return $retval;
}

# MAIN()

   if ( $version =~ /VERSION\s+3/ ) {
     $fase = 'LeeCategorias';
   } else {
     die "El fichero no es un trapd.conf";
   }

   while ( <> ) {

       chop;

       if ( $fase eq 'LeeCategorias' ) {

	  if ( s/^CATEGORY\s+// ) {
	     chop;
	     my ($catnum, $cat, $catdesc) = split /"?\s"/;
	     $category{$catnum}{CATEGORY} = $cat;
             $category{$catnum}{DESCR} = $catdesc;
             $category{$catnum}{NEVENTS} = 0;
             # $category{$catnum}{EVENTS} = ();
             $category_to_num{$cat}=$catnum;
	     if ($catnum > $maxcat) { $maxcat = catnum; }
	  }

	  elsif ( ! /^#.*$/ ) {
	     $fase = 'LeeAcciones';
	  }
       } # LeeCategorias

       # Lee entradas ACTION num "id" accion......EOL (y si descripcion)

       if ( $fase eq 'LeeAcciones' ) {
	  my $actnum;
	  my $id;

	  if ( s/^ACTION\s+// ) {
	     my ($actnum, $id, $what) = split /\s*"/;
	     my $desc = obtieneDESC;
	     $action{$actnum} = {
		   ID => $id,
		   WHAT => $what,
		   DESC => $desc

		};
	  }

	  elsif ( ! /^#.*$/ ) {
	       $fase = 'LeeOID';
	  }
       } # LeeAcciones

       if ( $fase eq 'LeeOID' ) {

	  if ( s/^OID_ALIAS\s+//) {
	     my ($alias, $trap_oid) = split;
	     $oid{$trap_oid}{'ALIAS'}=$alias;
             $oid{$trap_oid}{'BASEOID'}=$trap_oid;
	  }

	  elsif ( ! /^#.*$/ ) {
	     $fase = 'LeeEventos';
          }
       } # LeeOID

       if ( $fase eq 'LeeEventos' ) {


	  if ( s/^#.*// ) { }

	  elsif ( s/^EVENT\s+// ) {
	      my $cat;
	      my $severity;
	      my $id;
	      my $foo;
	      ($foo, $cat, $severity) = split /\s*"\s*/;
	      ($id, $evoid) = split /\s+/ , $foo;

	      $category{$category_to_num{$cat}}{'NEVENTS'}++;
	      push @{$category{$category_to_num{$cat}}{'EVENTS'}}, $evoid;

	      $event{$evoid} = {
		 ID => $id,
		 CATEGORY => $cat,
		 SEVERITY => $severity
		 };

	  }

	  elsif ( s/^FORMAT\s+// ) {
	      $event{$evoid}{'FORMAT'} = $_;
	  }

	  elsif ( s/^EXEC\s+// ) {
	      $event{$evoid}{'EXEC'} = $_;
	  }

	  elsif ( s/^SDESC\s*// ) {
	      $event{$evoid}{'DESC'} = obtieneDESC;
	  }

       } # LeeEventos

   }


# Creamos fichero de resultados

  open (OFD, "> eventos.html");

  print OFD '<html>
  <head>
   <title>Configuracion de trapd.con</title>
  </head>
  <body bgcolor=#ffffff>
  <h1>Volcado del trapd.conf de OpenView</h1>
  <hr>
  <a href="#eventos">[Acciones]</a>&nbsp
  <a href="#categorias">[Categorias]</a>&nbsp
  <a href="#OIDs">[OIDs]</a>&nbsp
  <a href="#eventos">[Eventos]</a>
  <hr>';

  # Volcamos las acciones en formato HTML

  print OFD '<a name="acciones"><h2>Acciones</h2></a><blockquote>';

  my $i;

  foreach $i (keys %action) {
     print OFD "<h3>$action{$i}{'ID'} ($i)</h3><br>
     <blockquote>
     <b>Descripcion:</b><blockquote>$action{$i}{'DESC'}</blockquote><br>
     <b>Accion:</b><blockquote><tt>$action{$i}{'WHAT'}</tt></blockquote><br>
     </blockquote><br>";
  }

  print OFD '</blockquote>';

  # Volcamos Categorias
  print OFD '<hr><a href="#eventos">[Acciones]</a>&nbsp<a href="#categorias">[Categorias]</a>&nbsp<a href="#OIDs">[OIDs]</a>&nbsp<a href="#eventos">[Eventos]</a>\n';

  print OFD '<a name="categorias"><h2>Categorias</h2></a><blockquote>';

  foreach $i (sort keys %category) {
     print OFD "<h3>$category{$i}{'CATEGORY'} ($category{$i}{'NEVENTS'} eventos)</h3><br>";
     print OFD "<blockquote>";
     foreach my $o ( @{$category{$i}{'EVENTS'}} ) {
	print OFD "<a href=\"#event_$o\">$event{$o}{'ID'}</a><br>";
     }
     print OFD "</blockquote>";
  }
  print OFD '</blockquote>';

  # Volcamos OIDs

  print OFD '<hr><a href="#eventos">[Acciones]</a>&nbsp<a href="#categorias">[Categorias]</a>&nbsp<a href="#OIDs">[OIDs]</a>&nbsp<a href="#eventos">[Eventos]</a>\n';
  print OFD '<a name="OIDs"><h2>OIDs</h2></a><blockquote>';

  print OFD '<table align="center" border="1" summary="OID alias definidos en trapd.conf">';
  print OFD "\t<caption>OID Alias</caption>\n";
  print OFD "\t<tr><th>Alias</th><th>OID</th></tr>\n";

  foreach $i (sort keys %oid) {
     print OFD "\t<tr><td align=\"right\">$oid{$i}{'ALIAS'}</td> <td align=\"left\">$i</td></tr>\n";
  }

  print OFD '</table>';

  # Volcamos eventos

  print OFD '<hr><a href="#eventos">[Acciones]</a>&nbsp<a href="#categorias">[Categorias]</a>&nbsp<a href="#OIDs">[OIDs]</a>&nbsp<a href="#eventos">[Eventos]</a>\n';
  print OFD '<a name="eventos"><h2>Eventos</h2></a><blockquote>';

  foreach $i (keys %event) {
     print OFD "<a name=\"event_$i\">
     <h3>[$event{$i}{'SEVERITY'}] - $event{$i}{'ID'} ($i)</h3><br>
     <blockquote>
     <b>OID:</b> $i<br>
     <b>Category:</b> $event{$i}{'CATEGORY'}<br>
     <b>Formato:</b> $event{$i}{'FORMAT'}<br>";

     if ( defined $event{$i}{'EXEC'} ) {
	print OFD "<b>Exec:</b> $event{$i}{'EXEC'}<br>";
     } else {
	print OFD "<b>Exec:</b> <i>(nada)</i><br>";
     }

     print OFD "<b>Descripcion:</b><blockquote><tt>$event{$i}{'DESC'}</tt></blockquote></blockquote><br>";

  }

  print OFD '</blockquote>';

  # Pie de pagina y cierre del html

  print OFD '</blockquote></body></html>';

#EOF#
