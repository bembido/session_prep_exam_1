import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF245B8E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Подготовка к экзамену',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const QuizScreen(),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final Future<List<QuizQuestion>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture =
        const DocxQuizParser('assets/PO 5.1-5.3 answers.docx').loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuizQuestion>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось прочитать файл с вопросами.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final questions = snapshot.data ?? <QuizQuestion>[];
        if (questions.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Вопросы не найдены.'),
            ),
          );
        }

        return QuizSession(questions: questions);
      },
    );
  }
}

class QuizSession extends StatefulWidget {
  const QuizSession({super.key, required this.questions});

  final List<QuizQuestion> questions;

  @override
  State<QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends State<QuizSession> {
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _showResult = false;
  bool _showSummary = false;
  late List<int?> _selectedByQuestion;
  late List<bool?> _resultByQuestion;

  @override
  void initState() {
    super.initState();
    _selectedByQuestion = List<int?>.filled(widget.questions.length, null);
    _resultByQuestion = List<bool?>.filled(widget.questions.length, null);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подготовка к экзамену'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showSummary
              ? _buildSummary(context)
              : _buildQuestionView(context, question),
        ),
      ),
    );
  }

  Widget _buildQuestionView(BuildContext context, QuizQuestion question) {
    final total = widget.questions.length;
    final correctCount =
        _resultByQuestion.where((result) => result == true).length;
    final keyedCount =
        widget.questions.where((q) => q.correctIndex != null).length;
    final answerKeyCount =
        widget.questions.where((q) => q.answerLabel != null).length;
    final mismatchCount =
        widget.questions.where((q) => q.answerMismatch).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.section != null)
            Text(
              question.section!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Вопрос ${_currentIndex + 1}/$total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Правильно: $correctCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / total,
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text(
            'Ключи: $keyedCount из $total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (answerKeyCount > 0)
            Text(
              mismatchCount == 0
                  ? 'Проверка ключей: без ошибок'
                  : 'Проверка ключей: $mismatchCount ошибок',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mismatchCount == 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                question.question,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildOptionTile(context, question, index);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildResultHint(context, question),
          const SizedBox(height: 12),
          _buildFooter(context, question),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    QuizQuestion question,
    int index,
  ) {
    final option = question.options[index];
    final isSelected = _selectedIndex == index;
    final hasKey = question.correctIndex != null;
    final isCorrect = option.isCorrect;

    Color borderColor = Theme.of(context).dividerColor;
    Color fillColor = Colors.transparent;
    IconData? icon;

    if (_showResult && hasKey) {
      if (isCorrect) {
        borderColor = Colors.green.shade600;
        fillColor = Colors.green.shade50;
        icon = Icons.check_circle;
      } else if (isSelected) {
        borderColor = Colors.red.shade400;
        fillColor = Colors.red.shade50;
        icon = Icons.cancel;
      }
    } else if (isSelected) {
      borderColor = Theme.of(context).colorScheme.primary;
      fillColor = Theme.of(context).colorScheme.primary.withOpacity(0.08);
    }

    final label = String.fromCharCode(65 + index);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showResult
          ? null
          : () {
              setState(() {
                _selectedIndex = index;
                _selectedByQuestion[_currentIndex] = index;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: borderColor,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (icon != null) Icon(icon, color: borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHint(BuildContext context, QuizQuestion question) {
    if (!_showResult) {
      return const SizedBox.shrink();
    }

    if (question.correctIndex == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'В файле нет правильного ответа для этого вопроса.',
        ),
      );
    }

    final correct = question.options[question.correctIndex!];
    final label = String.fromCharCode(65 + question.correctIndex!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Правильный ответ: $label) ${correct.text}',
        style: TextStyle(color: Colors.green.shade900),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, QuizQuestion question) {
    final isLast = _currentIndex == widget.questions.length - 1;
    final hasSelection = _selectedIndex != null;

    final primaryLabel = _showResult
        ? (isLast ? 'Результаты' : 'Дальше')
        : 'Проверить';

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _showResult ? _nextQuestion : _checkAnswer,
            child: Text(primaryLabel),
          ),
        ),
        if (!_showResult) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: hasSelection ? _clearSelection : null,
            child: const Text('Сбросить'),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final total = widget.questions.length;
    final answered =
        _selectedByQuestion.where((answer) => answer != null).length;
    final withKey = _resultByQuestion.where((result) => result != null).length;
    final correct = _resultByQuestion.where((result) => result == true).length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Готово!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Вопросов: $total'),
                Text('Отвечено: $answered'),
                Text('С ключом: $withKey'),
                Text('Правильных: $correct'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _restart,
                  child: const Text('Начать заново'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _checkAnswer() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ответ.')),
      );
      return;
    }

    final question = widget.questions[_currentIndex];
    final hasKey = question.correctIndex != null;

    setState(() {
      _showResult = true;
      if (hasKey) {
        _resultByQuestion[_currentIndex] =
            question.options[_selectedIndex!].isCorrect;
      }
    });
  }

  void _nextQuestion() {
    final isLast = _currentIndex == widget.questions.length - 1;

    setState(() {
      if (isLast) {
        _showSummary = true;
        return;
      }

      _currentIndex++;
      _selectedIndex = _selectedByQuestion[_currentIndex];
      _showResult = _resultByQuestion[_currentIndex] != null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndex = null;
      _selectedByQuestion[_currentIndex] = null;
    });
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _showResult = false;
      _showSummary = false;
      _selectedByQuestion =
          List<int?>.filled(widget.questions.length, null);
      _resultByQuestion = List<bool?>.filled(widget.questions.length, null);
    });
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.question,
    required this.options,
    this.section,
    this.answerLabel,
    this.answerText,
    this.answerMismatch = false,
  });

  String question;
  final List<QuizOption> options;
  final String? section;
  String? answerLabel;
  String? answerText;
  bool answerMismatch;

  int? get correctIndex {
    final index = options.indexWhere((option) => option.isCorrect);
    return index == -1 ? null : index;
  }
}

class QuizOption {
  QuizOption({required this.text, required this.isCorrect});

  final String text;
  final bool isCorrect;

  QuizOption copyWith({String? text, bool? isCorrect}) {
    return QuizOption(
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}

class DocxQuizParser {
  const DocxQuizParser(this.assetPath);

  final String assetPath;

  Future<List<QuizQuestion>> loadQuestions() async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (file) => file.name == 'word/document.xml',
    );
    final xmlContent = utf8.decode(docFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    final paragraphs = _readParagraphs(document);
    final questions = _buildQuestions(paragraphs);
    _shuffleQuestions(questions);
    return questions;
  }

  List<_Paragraph> _readParagraphs(XmlDocument document) {
    const wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    final paragraphs = <_Paragraph>[];

    for (final p in document.findAllElements('p', namespace: wNs)) {
      final segments = <_Segment>[];
      var paragraphBold = false;

      for (final r in p.findAllElements('r', namespace: wNs)) {
        final rPr = r.getElement('rPr', namespace: wNs);
        final isBold = rPr?.getElement('b', namespace: wNs) != null;
        if (isBold) {
          paragraphBold = true;
        }

        final buffer = StringBuffer();
        for (final node in r.children) {
          if (node is XmlElement) {
            if (node.name.local == 't') {
              buffer.write(node.text);
            } else if (node.name.local == 'tab') {
              buffer.write('\t');
            } else if (node.name.local == 'br') {
              buffer.write('\n');
            }
          }
        }

        final text = buffer.toString();
        if (text.isNotEmpty) {
          segments.add(_Segment(text: text, isBold: isBold));
        }
      }

      final paragraphText = segments.map((s) => s.text).join();
      if (paragraphText.trim().isNotEmpty) {
        paragraphs.add(
          _Paragraph(
            text: paragraphText,
            segments: segments,
            isBold: paragraphBold,
          ),
        );
      }
    }

    return paragraphs;
  }

  List<QuizQuestion> _buildQuestions(List<_Paragraph> paragraphs) {
    final questions = <QuizQuestion>[];
    String? currentSection;
    QuizQuestion? currentQuestion;

    final questionPattern = RegExp(r'^(\d+)\.\s*(.+)$', dotAll: true);
    final sectionPattern = RegExp(r'^(РО|RO)\s+\d', caseSensitive: false);
    final optionMarker = RegExp(r'[A-E][).]');
    final answerPattern = RegExp(
      r'^(Answer|Ответ)\s*:\s*([A-E])(?:\s*[\u2013\u2014-]\s*(.+))?$',
      caseSensitive: false,
    );

    for (final paragraph in paragraphs) {
      final text = paragraph.text.trim();
      if (text.isEmpty) {
        continue;
      }

      final match = questionPattern.firstMatch(text);
      if (match != null) {
        final remainder = match.group(2)!.trim();
        final optionStart = optionMarker.firstMatch(remainder);
        final questionText = optionStart == null
            ? remainder
            : remainder.substring(0, optionStart.start).trim();
        currentQuestion = QuizQuestion(
          question: questionText,
          options: [],
          section: currentSection,
        );
        questions.add(currentQuestion);
        final inlineOptions = _extractOptions(paragraph);
        if (inlineOptions.isNotEmpty) {
          currentQuestion.options.addAll(inlineOptions);
        }
        continue;
      }

      final answerKey = _parseAnswerLine(text, answerPattern);
      if (answerKey != null) {
        if (currentQuestion != null) {
          currentQuestion.answerLabel = answerKey.label;
          currentQuestion.answerText = answerKey.text;
        }
        continue;
      }

      if (sectionPattern.hasMatch(text) ||
          (paragraph.isBold && !optionMarker.hasMatch(text))) {
        currentSection = text;
        continue;
      }

      final options = _extractOptions(paragraph);
      if (options.isNotEmpty && currentQuestion != null) {
        currentQuestion.options.addAll(options);
        continue;
      }

      if (currentQuestion != null && currentQuestion.options.isEmpty) {
        currentQuestion.question = '${currentQuestion.question} $text';
      }
    }

    for (final question in questions) {
      if (question.answerLabel != null) {
        question.answerMismatch = _applyAnswerKey(question);
      }
    }

    return questions.where((q) => q.options.length >= 2).toList();
  }

  void _shuffleQuestions(List<QuizQuestion> questions) {
    final random = Random();
    questions.shuffle(random);
    for (final question in questions) {
      question.options.shuffle(random);
    }
  }

  _AnswerKey? _parseAnswerLine(String text, RegExp answerPattern) {
    final match = answerPattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    final label = match.group(2)!.toUpperCase();
    final answerText = match.group(3)?.trim();
    return _AnswerKey(label: label, text: answerText);
  }

  bool _applyAnswerKey(QuizQuestion question) {
    final label = question.answerLabel;
    if (label == null) {
      return false;
    }
    final index = label.codeUnitAt(0) - 65;
    if (index < 0 || index >= question.options.length) {
      return true;
    }

    for (var i = 0; i < question.options.length; i++) {
      final option = question.options[i];
      question.options[i] = option.copyWith(isCorrect: i == index);
    }

    final answerText = question.answerText;
    if (answerText == null || answerText.isEmpty) {
      return false;
    }
    return _normalizeAnswer(answerText) !=
        _normalizeAnswer(question.options[index].text);
  }

  String _normalizeAnswer(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<QuizOption> _extractOptions(_Paragraph paragraph) {
    final text = paragraph.text;
    final matches = RegExp(r'([A-E])[).]').allMatches(text).toList();
    if (matches.isEmpty) {
      return [];
    }

    final spans = <_SegmentSpan>[];
    var offset = 0;
    for (final segment in paragraph.segments) {
      final length = segment.text.length;
      if (length == 0) {
        continue;
      }
      spans.add(
        _SegmentSpan(
          start: offset,
          end: offset + length,
          isBold: segment.isBold,
        ),
      );
      offset += length;
    }

    final options = <QuizOption>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final start = match.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      var raw = text.substring(start, end).trim();
      if (raw.isEmpty) {
        continue;
      }

      final hasBold = _hasBoldInRange(spans, start, end);
      final markerCorrect = _hasCorrectMarker(raw);
      raw = _stripCorrectMarker(raw);
      raw = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (raw.isEmpty) {
        continue;
      }

      options.add(
        QuizOption(
          text: raw,
          isCorrect: hasBold || markerCorrect,
        ),
      );
    }

    return options;
  }

  bool _hasBoldInRange(List<_SegmentSpan> spans, int start, int end) {
    for (final span in spans) {
      if (!span.isBold) {
        continue;
      }
      final overlaps = span.end > start && span.start < end;
      if (overlaps) {
        return true;
      }
    }
    return false;
  }

  bool _hasCorrectMarker(String text) {
    final trimmed = text.trimLeft();
    final marker = RegExp(r'^(\*|\+|✔|✓|☑|\[x\]|\(x\))',
        caseSensitive: false);
    if (marker.hasMatch(trimmed)) {
      return true;
    }
    final inlineMarker = RegExp(r'\((correct|правильн)\w*\)',
        caseSensitive: false);
    return inlineMarker.hasMatch(trimmed);
  }

  String _stripCorrectMarker(String text) {
    var result = text.trimLeft();
    result = result.replaceFirst(
      RegExp(r'^(\*|\+|✔|✓|☑|\[x\]|\(x\))\s*',
          caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\((correct|правильн)\w*\)', caseSensitive: false),
      '',
    );
    return result.trim();
  }
}

class _Paragraph {
  _Paragraph({
    required this.text,
    required this.segments,
    required this.isBold,
  });

  final String text;
  final List<_Segment> segments;
  final bool isBold;
}

class _Segment {
  _Segment({required this.text, required this.isBold});

  final String text;
  final bool isBold;
}

class _SegmentSpan {
  _SegmentSpan({
    required this.start,
    required this.end,
    required this.isBold,
  });

  final int start;
  final int end;
  final bool isBold;
}

class _AnswerKey {
  const _AnswerKey({required this.label, this.text});

  final String label;
  final String? text;
}
