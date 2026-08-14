import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final minCoverage = args.isEmpty ? 10.0 : double.parse(args.first);
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found; run flutter test --coverage first.',
    );
    exitCode = 1;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  await for (final line
      in lcov
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  if (linesFound == 0) {
    stderr.writeln('coverage/lcov.info contains no line records.');
    exitCode = 1;
    return;
  }

  final coverage = linesHit * 100 / linesFound;
  stdout.writeln(
    'Flutter coverage: ${coverage.toStringAsFixed(2)}% ($linesHit/$linesFound), minimum ${minCoverage.toStringAsFixed(2)}%',
  );
  if (coverage < minCoverage - 1e-9) {
    stderr.writeln('Coverage below minimum threshold.');
    exitCode = 1;
  }
}
