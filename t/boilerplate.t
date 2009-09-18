use Test::Base;
use Data::Patch;

filters
  (
   {
    template        => [qw/eval gdt/],
    template_static => [qw/eval gdt_parse/],
    patched         => [qw/eval/],
    parsed          => [qw/eval/],
   }
  );

my $face =
  sub{
    my $data = shift;
    if($data eq 'smile'){
      return sub{':)'};
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
    }elsif($data eq 'smile-static'){
      return ':)';
    }
    return ();
  };

sub gdt{
  my $template = shift;
  my($patch, $parsed) = Data::Patch->parse($template, $face);
  my $patched = Data::Patch->patch($parsed, $patch);
  return $patched;
}

sub gdt_parse{
  my $template = shift;
  my($patch, $parsed) = Data::Patch->parse($template, $face);
  return $parsed;
}

run_compare template => 'patched';
run_compare template_static => 'parsed';

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
=== test five
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
