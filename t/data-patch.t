use Test::Base;
use Data::Patch;

filters
  (
   {
    template        => [qw/eval gdt/],
    template2       => [qw/eval gdt2/],
    template_static => [qw/eval gdt_parse/],
    patched         => [qw/eval/],
    parsed          => [qw/eval/],
   }
  );

my $face =
  sub{
    my $data = shift;
    if($data eq 'smile'){
      return sub{
        my($flg) = @{$_[1] || []}; return $flg ? '-smile-' : ':)'
      };
    }elsif($data eq 'smile2'){
      return sub{':-)'};
    }elsif($data eq 'depressed'){
      return sub{':('};
    }elsif($data eq 'depressed2'){
      return sub{':-('};
    }elsif($data eq 'smile-n-ref'){
      return sub{[qw/:) :-)/]};
    }elsif($data eq 'depressed-n-ref'){
      return sub{[qw/:( :-(/]};
    }elsif($data eq 'null'){
      return sub{''};
    }elsif($data eq 'smile-static'){
      return ':)';
    }elsif($data eq 'null-static'){
      return "";
    }
    return ();
  };

sub gdt{
  my $template = shift;
  my($patch, $parsed) = Data::Patch->parse($template, $face);
  my $patched = Data::Patch->patch($parsed, $patch);
  return $patched;
}

sub gdt2{
  my $template = shift;
  my($patch, $parsed) = Data::Patch->parse($template, $face);
  use Clone;
  my $clone_parsed = Clone::clone($parsed);
  my $patched = Data::Patch->patch($clone_parsed, $patch, [1]);
  return $patched;
}

sub gdt_parse{
  my $template = shift;
  my($patch, $parsed) = Data::Patch->parse($template, $face);
  return $parsed;
}

run_compare template => 'patched';
run_compare template_static => 'parsed';
run_compare template2 => 'patched';


__END__
=== test one
--- template
   {
    a => 'smile',
    b => ['depressed', 2, 3],
    c => {
          a => 'smile2',
          b => ['depressed2', 2, 3]
         },
   };
--- patched
   {
    a => ':)',
    b => [':(', 2, 3],
    c => {
          a => ':-)',
          b => [':-(', 2, 3]
         },
   };
=== test two
--- template
   {
    a => 'smile-n-ref',
    b => ['smile-n-ref', 2, 3],
    c => {
          a => 'depressed-n-ref',
          b => ['depressed-n-ref', 2, 3]
         },
   };
--- patched
   {
    a => [':)', ':-)'],
    b => [[':)', ':-)'], 2, 3],
    c => {
          a => [':(', ':-('],
          b => [[':(', ':-('], 2, 3]
         },
   };
=== test three
--- template
   {
    a => [1, 2, [3, [4, [5, ['smile-n-ref']]]]],
    b => ['smile-n-ref', 2, 3],
    c => {
          a => 'depressed-n-ref',
          b => [ 1, {a => 1, b => 2 , c => 'depressed-n-ref', d => 5}, 2, ['depressed-n-ref']]
         },
   };
--- patched
   {
    a => [1, 2, [3, [4, [5, [[':)', ':-)']]]]]],
    b => [[':)', ':-)'], 2, 3],
    c => {
          a => [':(', ':-('],
          b => [ 1, {a => 1, b => 2 , c => [':(', ':-('], d => 5}, 2, [[':(', ':-(']]]
         },
   };
=== test four
--- template
   {
    a => 'null',
    b => ['null', "null", "null"],
    c => {
          a => 'null',
          b => ['null', "null", "null"]
         },
   };
--- patched
   {
    a => '',
    b => ['', "", ""],
    c => {
          a => '',
          b => ['', "", ""]
         },
   };
=== test five
--- template_static
   {
    a => 'smile-static',
    b => ['depressed', 2, 3],
    c => {
          a => 'smile2',
          b => ['depressed2', 2, 3]
         },
   };
--- parsed
   {
    a => ':)',
    b => ['depressed', 2, 3],
    c => {
          a => 'smile2',
          b => ['depressed2', 2, 3]
         },
   };
=== test six
--- template_static
   {
    a => 'smile-static',
    b => ['smile-static', 2, 3],
    c => {
          a => 'smile-static',
          b => ['smile-static', 2, 3]
         },
   };
--- parsed
   {
    a => ':)',
    b => [':)', 2, 3],
    c => {
          a => ':)',
          b => [':)', 2, 3]
         },
   };

=== test seven
--- template_static
   {
    a => 'null-static',
    b => ['null-static', "null-static", "null-static"],
    c => {
          a => 'null-static',
          b => ['null-static', "null-static", "null-static"]
         },
   };
--- parsed
   {
    a => '',
    b => ['', "", ""],
    c => {
          a => '',
          b => ['', "", ""]
         },
   };
=== test one gdt2
--- template2
   {
    a => 'smile',
    b => ['depressed', 2, 3],
    c => {
          a => 'smile2',
          b => ['depressed2', 2, 3]
         },
    d => [1,2,3,4, [{a => 'b'}, {a => {b => 'smile'}}]],
   };
--- patched
   {
    a => '-smile-',
    b => [':(', 2, 3],
    c => {
          a => ':-)',
          b => [':-(', 2, 3]
         },
    d => [1,2,3,4, [{a => 'b'}, {a => {b => '-smile-'}}]],
   };
