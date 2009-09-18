package Data::Patch;

use Clone ();
use strict;
use constant {
              ARRAY => 1,
              HASH  => 2,
              CODE  => 3,
             };

sub patch{
  shift if $_[0] eq __PACKAGE__;
  my($parsed_data, $patches, $option) = @_;
  my $data = Clone::clone($parsed_data);
  foreach my $order (@$patches){
    my $v = $data;
    my($code, $vref);
    foreach my $r (@$order){
      if(ref $r eq 'Data::Patch::code'){
        $code = $r;
      }else{
        ($vref, $v) = $r->($v);
      }
    }
    unless($code){
      $$vref = $v;
    }else{
      # $code->() is filter code ref
      $$vref = $code->()->($vref, $option);
    }
  }
  return $data;
}

sub parse{
  shift if $_[0] eq __PACKAGE__;
  my $option = {};
  $option = pop if ref $_[$#_] eq 'HASH';
  my($data, $sub, $keysub) = @_;
  Carp::croak('parse needs at least 1 argument as first argument') unless @_;
  unless($sub){
    my $sub_option = {};
    $sub_option->{vars} = $option->{vars} or Carp::croak("need vars key when you don't pass subroutine.");
    $sub_option->{tt} = Template->new({map {/^[A-Z_]+$/ ? ($_ => $option->{$_}) : () } keys %$option});
    $option->{auto_code} = 1;
    $sub = sub{
      my $s = shift;
      sub {
        my $o;
        $sub_option->{tt}->process(\$s, $sub_option->{vars}, \$o) || die $Template::ERROR, "\n";
        return $o;
      };
    };
  }
  $keysub ||= sub {shift};
  my %hash;
  my @order;  # will include the way to reach $data's leading edge of branch.
              # see _data_filter comment for $order.
  my @target; # target index of @order to be patched.
  my $new_data = _data_filter
    (
     $data,
     sub {
       my($data, $order) = @_;
       push(@order, $order);
       my $filter;
       if($filter = $sub->($data) and
          ($option->{auto_code} ? $filter->($data) ne $data : ref $filter eq 'CODE')
         ){
         push(@target, $#order);
         return bless [$data, $filter], 'Data::Patch::codex';
       }else{
         return $option->{auto_code} ? $data : defined $filter ? $filter : $data;
       }
     },
     $keysub,
     [],
    );

  my @patch;
  foreach my $n (@target){
    push @patch, [];
    for(my $i = 0; $i < @{$order[$n]}; $i += 2){
      my $value_code;
      if($order[$n]->[$i] == ARRAY){
        my $index = ${$order[$n]}[$i + 1];
        $value_code = sub { return (\${$_[0]}[$index], $_[0]->[$index]) };
      }elsif($order[$n]->[$i] == HASH){
        my $key = ${$order[$n]}[$i + 1];
        $value_code = sub { return (\${$_[0]}{$key}, $_[0]->{$key}) };
      }elsif($order[$n]->[$i] == CODE){
        my $code = ${$order[$n]}[$i + 1];
        $value_code = bless sub { return $code }, 'Data::Patch::code';
      }
      push @{$patch[$#patch]}, $value_code;
    }
  }
  return wantarray ? (\@patch, $new_data) : \@patch;
}

sub _data_filter{
  my($data, $sub, $keysub, $order) = @_;

  # $data is the data which parsed recursively
  # $sub is subroutine which modify value
  # $order include order how to reach current point.
  #
  #  for example;
  #    $hoge = [0, 1, 2, [0, 1, hoge => {a => 1, b => 2, c => 3}]];
  #
  # The order to reach $hoge->[3]->[2]->{c}, is
  #  (ARRAY => 3, ARRAY => 2, HASH => c);
  #
  # So, this means "$hoge->[3]->[2]->{c} is hash{c} of (array[2] of (array[3] of $data))"

  my $ref = ref $data;
  if($ref eq 'ARRAY'){
    my @tmp;
    foreach my $i (0 .. $#$data){
      my @order = (@$order, ARRAY() => $i);
      push @tmp, _data_filter($data->[$i], $sub, $keysub, \@order);
    }
    return \@tmp;
  }elsif($ref eq 'HASH'){
    my %tmp;
    while(my($k, $v) = each %$data){
      $k = $keysub->($k);
      my @order = (@$order, HASH() => $k);
      $tmp{$k} = _data_filter($v, $sub, $keysub, \@order);
    }
    return \%tmp;
  }else{
    my $v = $sub->($data, $order);
    if(ref $v eq 'Data::Patch::codex'){
      # $v is bless [$data, $filter], 'Data::Patch::codex';
      push(@$order, CODE() => $v->[1]);    # 2 means CODE
      return $v->[0];
    }else{
      return $v;
    }
  }
}

=head1 NAME

Data::Patch - parsing and patching the data

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 use Data::Patch;
 
 my $original =
   {
    a => 'localtime',
    b => ['localtime', 2, 3],
    c => {
          a => 'hostname',
          b => ['localtime', 2, 3]
         },
   };
 
 my($patch, $parsed) =
     Data::Patch->parse
        (
          $original,
          sub{
            my $s = shift;
            if($s eq 'localtime'){
               return sub{scalar(localtime)};
            }elsif($s eq 'hostname'){
               return `hostname`;
            }
            return;
        );
 
 ...
 
 my $patched = Data::Patch->patch($parsed, $patch);
 
 print Data::Dumper::Dumper($parsed, $patched);
 
 # instead of Data::Template
 
 use Template; # This module don't do "use Template;" automatically.
 
 my $tt = {
     who => 'me',
     to => '${a}',
     subject => 'Important - trust me',
     body => <<'BODY',
 
          When I was ${b}, I realized that
          I had not ${c}. Do you?
 BODY
 };
 
 my $patch = Data::Patch->parse($tt, {INTERPOLATE  => 1, vars => $vars});
 my $patched = Data::Patch->patch($tt, $patch);

=head1 DESCRIPTION

You need data of which almost all are not changed,
but some of values in the data are dynamically changed.
And this data is repeatably used, so you won't do parsing more than once.

 my $original =
   {
    a => 'localtime',
    b => ['localtime', 2, 3],
    c => {
          a => 'hostname',
          b => ['localtime', 2, 3]
         },
   };

In this data, you want replace 'localtime' with result of sub {scalar(localtime)} and
you want change 'hostname' to current server's hostname.

In this case, you can write the function to parse data recursively and to modify the value.
But if you want need such a data every time and, in another similar case, your data is too big,
the speed of recursive function is much slower.

This module, at first parse such a data.

 ($patch, $parsed) = Data::Patch->parse
                       ($original,
                        sub{
                          my $d = shift;
                          if($d eq 'localtime'){
                            return sub{scalar(localtime)};
                          }elsif($d eq 'hostname'){
                            return 'YOUR_HOSTNAME';
                          }
                          return ();
                       );

$parsed is as following.

 $parsed =
   {
    a => 'localtime',
    b => ['localtime', 2, 3],
    c => {
          a => 'YOUR_HOSTNAME',
          b => ['localtime', 2, 3]
         },
   };

$patch is like as following.

 $patch= [
          [
            sub {(\${$_[0]}{'c'}, $_[0]->{'c'})},
            sub {(\${$_[0]}{'b'}, $_[0]->{'b'})},
            sub {(\${$_[0]}[0], $_[0]->[0])},
            sub {sub{scalar(localtime)}},
          ],
          [
            sub {(\${$_[0]}{'a'}, $_[0]->{'a'})},
            sub {sub{scalar(localtime)}},
          ],
          [
            sub {(\${$_[0]}{'b'}, $_[0]->{'b'})},
            sub {(\${$_[0]}[0], $_[0]->[0])},
            sub {sub{scalar(localtime)}},
          ]
        ];

patch it to parsed_data.

 $patched = Data::Patch->patch($parsed, $patch);

$patched is as following.

 $parsed =
   {
    a => 'Wed Oct  4 17:05:56 2006',
    b => ['Wed Oct  4 17:05:56 2006', 2, 3],
    c => {
          a => 'YOUR_HOSTNAME',
          b => ['Wed Oct  4 17:05:56 2006', 2, 3]
         },
   };

If you save parsed data and patch. Just use patch method.
This method won't parse data while patching. So, it should be faster.

=head1 FUNCTIONS/METHODS

=head2 parse

 ($parsed, $patch) = Data::Patch->parse($data, \&value_coderef [, \&key_coderef ]);

&value_coderef's argument is each data and $option of C<patch>.
This have to check these data and return 3 kinds of value.

=head3 return value of \&value_coderef

=over 4

=item code ref

The code ref will be applied when data is patched.

=item value

Data will be changed.
It is for statically modified value.

=item false

Data will not changed.

=back

=head3 return value of \&key_coderef

&key_coderef is optional. Its argument is key of hash. This is just a filter.
If you don't specify this, following coderef will be used.

 sub { shift }

=head2 parse($data, \&value_coderef, [\&key_coderef], \%options)

When you pass hash ref as last argument to parse, it change behavior of parse.
Option can take following.

=over 4

=item auto_code => 1

If the return value of &value_coderef is different from value of $data,
the C<return value of \&value_coderef>(explain above) is understood
as C<code ref> which is &value_coderef itself.

=back

=head2 parse($data, [undef, \&key_coderef,] \%options)

This usage is made as alternative of L<Data::Template>.

When you pass only $data and \%options or pass undef instead of &value_coderef,
the default subroutine will be used, which is like following.
(note: this module don't use Tempalte, automatically, so you have to "use Template").

    sub {
      my $s = shift;
      my $tt = Template->new({map {/^[A-Z_]+$/ ? ($_ => $option->{$_}) : () } keys %$option});
      my $vars = $option->{vars};
      sub {
        my $o;
        $tt->process(\$s, $vars, \$o) || die $Template::ERROR, "\n";
        return $o;
      };
    }

In this case, you can pass following options (auto_code option is automatically set true).

=over 4

=item vars => \%vars

\%vars is used as $vars in above code. It is used as arguments of process method.
In this case, this option is required.

=item capital letters

It is understood as argument of Template module.

 Template->new({map {/^[A-Z_]+$/ ? ($_ => $option->{$_}) : () } keys %$option});

=back

=head2 patch

 $patched = Data::Patch->patch($parsed, $patch, $options);

$options is passed to value_coderef which is explained in C<parce>.

=head1 AUTHOR

Ktat, C<< <ktat.is at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-data-patch at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Patch>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Patch

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Patch>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Patch>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Patch>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Patch>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Ktat, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Data::Patch
