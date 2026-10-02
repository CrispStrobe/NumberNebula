// CLI and playable HTML use the same pure Dart engine as the app.
// ignore_for_file: constant_identifier_names, avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:space_math_academy/features/games/services/sokoban_generator.dart'
    as engine;
import 'package:space_math_academy/features/games/services/sokoban_generator.dart'
    show Level;
export 'package:space_math_academy/features/games/services/sokoban_generator.dart'
    hide generate;

Level generate(int difficulty,
        {int? seed,
        int maxAttempts = 250,
        double? timeBudget,
        bool verbose = false}) =>
    engine.generate(difficulty,
        seed: seed,
        maxAttempts: maxAttempts,
        timeBudget: timeBudget,
        onAttempt: verbose ? stderr.writeln : null);

// ---------------------------------------------------------------- HTML pack
const String _HTML_PAGE = r'''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Sokoban pack</title>
<style>
 body{background:#1b1e24;color:#e6e6e6;font-family:ui-monospace,monospace;
      display:flex;flex-direction:column;align-items:center;padding:20px}
 h1{font-size:18px} #info{margin:6px 0 14px;color:#9aa}
 #board{line-height:1}
 .row{display:flex}
 .cell{width:34px;height:34px;display:flex;align-items:center;
       justify-content:center;font-size:22px}
 .wall{background:#3a4150;border-radius:4px;box-shadow:inset 0 -3px 0 #2b303c}
 .floor{background:#232833}.goal{background:#232833}
 .goal::after{content:'';position:absolute;width:10px;height:10px;
       border-radius:50%;background:#c98f2d}
 .cell{position:relative}
 .box{width:26px;height:26px;background:#b06a3b;border-radius:5px;
      box-shadow:inset 0 -4px 0 #8a4f28;z-index:1}
 .box.on{background:#d9a441;box-shadow:inset 0 -4px 0 #a87d2c}
 .player{width:24px;height:24px;background:#5aa9e6;border-radius:50%;
      box-shadow:inset 0 -4px 0 #3d7fb3;z-index:1}
 #msg{height:24px;color:#7ee787;margin-top:10px}
 button{background:#2e3542;color:#e6e6e6;border:0;border-radius:6px;
      padding:6px 12px;margin:0 4px;cursor:pointer}
</style></head><body>
<h1>Sokoban pack</h1>
<div id="info"></div>
<div id="board"></div>
<div id="msg"></div>
<div style="margin-top:10px">
 <button onclick="prev()">&#8592; level</button>
 <button onclick="undo()">undo (U)</button>
 <button onclick="reset()">restart (R)</button>
 <button onclick="next()">level &#8594;</button>
</div>
<p style="color:#778">arrow keys / WASD to move</p>
<script>
const LEVELS = __LEVELS__;
let li=0, grid, player, hist;
function load(){
  const rows = LEVELS[li].map.split("\n");
  grid = rows.map(r=>r.split(""));
  hist=[];
  for(let r=0;r<grid.length;r++)for(let c=0;c<grid[r].length;c++){
    const ch=grid[r][c];
    if(ch=='@'||ch=='+'){player=[r,c];grid[r][c]= ch=='+'?'.':' ';}
  }
  draw();
  document.getElementById('info').textContent =
    'level '+(li+1)+'/'+LEVELS.length+'  ·  difficulty '+LEVELS[li].d+
    '  ·  optimal-ish pushes: '+LEVELS[li].pushes;
  document.getElementById('msg').textContent='';
}
function cellAt(r,c){return (grid[r]&&grid[r][c])||'#';}
function setCell(r,c,ch){grid[r][c]=ch;}
function draw(){
  const b=document.getElementById('board');b.innerHTML='';
  for(let r=0;r<grid.length;r++){
    const row=document.createElement('div');row.className='row';
    for(let c=0;c<grid[r].length;c++){
      const ch=cellAt(r,c);
      const cell=document.createElement('div');
      cell.className='cell '+(ch=='#'?'wall':(ch=='.'||ch=='*')?'goal':'floor');
      if(ch=='$'||ch=='*'){const bx=document.createElement('div');
        bx.className='box'+(ch=='*'?' on':'');cell.appendChild(bx);}
      if(player[0]==r&&player[1]==c){const pl=document.createElement('div');
        pl.className='player';cell.appendChild(pl);}
      row.appendChild(cell);
    }
    b.appendChild(row);
  }
}
function move(dr,dc){
  const [r,c]=player, nr=r+dr, nc=c+dc, ch=cellAt(nr,nc);
  if(ch=='#')return;
  const snap=JSON.stringify({g:grid,p:player});
  if(ch=='$'||ch=='*'){
    const br=nr+dr, bc=nc+dc, bch=cellAt(br,bc);
    if(bch=='#'||bch=='$'||bch=='*')return;
    setCell(br,bc, bch=='.'?'*':'$');
    setCell(nr,nc, ch=='*'?'.':' ');
  }
  hist.push(snap);
  player=[nr,nc];draw();check();
}
function check(){
  for(const row of grid)for(const ch of row)if(ch=='$')return;
  document.getElementById('msg').textContent='Solved!  → next level';
}
function undo(){if(!hist.length)return;const s=JSON.parse(hist.pop());
  grid=s.g;player=s.p;draw();}
function reset(){load();}
function next(){li=(li+1)%LEVELS.length;load();}
function prev(){li=(li+LEVELS.length-1)%LEVELS.length;load();}
document.addEventListener('keydown',e=>{
  const k=e.key.toLowerCase();
  if(k=='arrowup'||k=='w')move(-1,0);
  else if(k=='arrowdown'||k=='s')move(1,0);
  else if(k=='arrowleft'||k=='a')move(0,-1);
  else if(k=='arrowright'||k=='d')move(0,1);
  else if(k=='r')reset(); else if(k=='u')undo(); else return;
  e.preventDefault();
});
load();
</script></body></html>
''';

void exportHtml(List<Level> levels, String path) {
  final data = [
    for (final lv in levels)
      {
        'd': lv.stats['difficulty'],
        'pushes': lv.stats['pushes'],
        'map': lv.ascii(),
      }
  ];
  final html = _HTML_PAGE.replaceFirst('__LEVELS__', jsonEncode(data));
  File(path).writeAsStringSync(html);
}

// ---------------------------------------------------------------- CLI
void main(List<String> argv) {
  int difficulty = 5;
  int count = 1;
  int? seed;
  double? timeBudget;
  bool solution = false;
  bool verbose = false;
  String? htmlPath;
  String? demoPath;

  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    String next() => argv[++i];
    switch (a) {
      case '-d':
      case '--difficulty':
        difficulty = int.parse(next());
      case '-n':
      case '--count':
        count = int.parse(next());
      case '--seed':
        seed = int.parse(next());
      case '--time-budget':
        timeBudget = double.parse(next());
      case '--solution':
        solution = true;
      case '-v':
      case '--verbose':
        verbose = true;
      case '--html':
        htmlPath = next();
      case '--demo':
        demoPath = next();
      case '-h':
      case '--help':
        _printUsage();
        return;
      default:
        if (a.startsWith('-')) {
          stderr.writeln('unknown option: $a');
          _printUsage();
          exit(2);
        }
    }
  }

  final rng = math.Random(seed);
  final levels = <Level>[];

  if (demoPath != null) {
    for (var d = 1; d <= 10; d++) {
      final lv = generate(d,
          seed: rng.nextInt(1 << 30), verbose: verbose, timeBudget: timeBudget);
      levels.add(lv);
      final tgt = (lv.stats['meets_target'] as bool) ? '' : '  (best effort)';
      print('difficulty $d: pushes=${lv.stats['pushes']} '
          'changes=${lv.stats['box_changes']} score=${lv.stats['score']}$tgt');
    }
    exportHtml(levels, demoPath);
    print('\nplayable pack written to $demoPath');
    return;
  }

  for (var i = 0; i < count; i++) {
    final s = seed == null ? null : rng.nextInt(1 << 30);
    final lv =
        generate(difficulty, seed: s, verbose: verbose, timeBudget: timeBudget);
    levels.add(lv);
    final st = lv.stats;
    final tgt = (st['meets_target'] as bool) ? '' : '  (best effort)';
    print('; difficulty ${st['difficulty']}  pushes ${st['pushes']}  '
        'moves ${st['moves']}  box-changes ${st['box_changes']}  '
        'counter ${st['counter_pushes']}  nodes ${st['nodes']}  '
        'score ${st['score']}$tgt');
    print(lv.ascii());
    if (solution) print('; solution: ${lv.solution}');
    print('');
  }
  if (htmlPath != null) {
    exportHtml(levels, htmlPath);
    print('playable pack written to $htmlPath');
  }
}

void _printUsage() {
  print('Sokoban level generator (Dart port)');
  print('Usage:');
  print('  dart run tool/sokoban_generator.dart [-d N] [-n N] [--seed N]');
  print('       [--solution] [--html FILE] [--demo FILE] [-v]');
  print('  -d, --difficulty N   difficulty 1..10 (default 5)');
  print('  -n, --count N        number of levels (default 1)');
  print('      --seed N         RNG seed (reproducible)');
  print(
      '      --time-budget N  limit generation work in seconds (best effort)');
  print('      --solution       print the LURD solution');
  print('      --html FILE      write levels into a playable HTML file');
  print('      --demo FILE      one level per difficulty 1..10 into HTML');
  print('  -v, --verbose        log attempt metrics to stderr');
}
