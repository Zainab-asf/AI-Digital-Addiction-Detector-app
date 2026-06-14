import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/usage_log.dart';
import '../../services/scoring_engine.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';

class _CoachMessage {
  _CoachMessage({
    required this.fromBot,
    required this.text,
    required this.time,
  });

  final bool fromBot;
  final String text;
  final DateTime time;
}

/// On-device rule-based wellness coach. Personalises responses using the
/// current [Prediction] and today's [DailyUsage] without contacting an LLM.
class _CoachBrain {
  _CoachBrain({
    required this.prediction,
    required this.today,
    required this.firstName,
    required this.dailyLimit,
  });

  final Prediction? prediction;
  final DailyUsage? today;
  final String firstName;
  final int dailyLimit;

  String greeting() {
    final p = prediction;
    final t = today;
    if (p == null || t == null) {
      return 'Hi $firstName! I\'m your LoopAware coach. Once your usage data '
          'loads I can suggest a plan tailored to today.';
    }
    final headline = p.wellnessLabel.toLowerCase();
    return 'Hi $firstName 👋  Today is shaping up as a "$headline" day. '
        'You\'ve used your phone for ${Formatters.duration(t.totalMinutes)} '
        'so far. Ask me about focus, sleep, your top apps — or tap a prompt '
        'below.';
  }

  List<String> quickPrompts() {
    return const [
      'Plan my next 24 hours',
      'Why am I checking my phone so much?',
      'How do I sleep better?',
      'I need a focus block',
    ];
  }

  String reply(String input) {
    final text = input.toLowerCase().trim();
    final p = prediction;
    final t = today;
    if (p == null || t == null) {
      return 'I need today\'s usage data first. Try pulling to refresh on the '
          'dashboard.';
    }

    if (_match(text, ['plan', 'day', 'next 24', 'tomorrow', 'schedule'])) {
      return _dailyPlan(p, t);
    }
    if (_match(text, [
      'dataset',
      'train a model',
      'training data',
      'model choose',
      'which model',
      'machine learning',
      'neural network',
      'classification',
      'regression',
      'fine tune',
      'fine-tune',
      'llm',
      'rag',
    ])) {
      return _modelAdvice(text);
    }
    if (_match(text, ['focus', 'concentrate', 'attention', 'work', 'study'])) {
      return _focusAdvice(p, t);
    }
    if (_match(text, ['sleep', 'bed', 'tired', 'night', 'rest'])) {
      return _sleepAdvice(p, t);
    }
    if (_match(text, [
      'scroll',
      'check',
      'pickup',
      'pick up',
      'loop',
      'compulsive',
      'instagram',
      'tiktok',
    ])) {
      return _loopAdvice(p, t);
    }
    if (_match(text, ['burnout', 'exhaust', 'overwhelm'])) {
      return _burnoutAdvice(p);
    }
    if (_match(text, ['screen time', 'limit', 'goal'])) {
      return _limitAdvice(t);
    }
    if (_match(text, ['hi', 'hello', 'hey', 'sup'])) {
      return 'Hey 👋  I\'m here if you need a focus reset, a sleep tip, or a '
          'plan for the rest of the day.';
    }
    return _fallback(p, t);
  }

  bool _match(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  String _dailyPlan(Prediction p, DailyUsage t) {
    final focusMins = ScoringEngine.suggestedFocusMinutes(t);
    final top = t.topApp;
    final overshoot = t.totalMinutes - dailyLimit;
    final buffer =
        StringBuffer()
          ..writeln('Here\'s a simple plan, $firstName:')
          ..writeln(
            '• Next ${focusMins * 2 + 5}m: one $focusMins-minute focus block, then a 5-minute walk.',
          )
          ..writeln(
            '• Evening: cap social/entertainment apps at 30 minutes total.${top != null && top.category.isDistracting ? ' ${top.appName} is your biggest pull today.' : ''}',
          )
          ..writeln(
            '• 22:00 onward: phone outside the bedroom. Your sleep score is ${p.sleepImpact.severity.label.toLowerCase()}.',
          );
    if (overshoot > 0) {
      buffer.writeln(
        '• Heads-up: you\'re already ${Formatters.duration(overshoot)} past your daily goal.',
      );
    } else {
      buffer.writeln(
        '• Bonus: you\'re still ${Formatters.duration(-overshoot)} under your goal — protect that buffer.',
      );
    }
    return buffer.toString().trim();
  }

  String _focusAdvice(Prediction p, DailyUsage t) {
    final mins = ScoringEngine.suggestedFocusMinutes(t);
    final avg = t.pickups == 0 ? 0 : (t.totalMinutes / t.pickups).round();
    return 'Your focus score is ${p.focus.score} (${p.focus.severity.label.toLowerCase()}). '
        'Average session is just ${avg}m, so try a $mins-minute focused '
        'block:\n\n'
        '1. Silence notifications.\n'
        '2. Phone in another room or face-down across the room.\n'
        '3. Single task for $mins minutes, then a 5-minute reward break.\n\n'
        'Two cycles will move the needle more than any tracking dashboard ever could.';
  }

  String _sleepAdvice(Prediction p, DailyUsage t) {
    final night = t.nightMinutes;
    final peak = Formatters.hourLabel(t.peakHour);
    return 'Sleep impact today is ${p.sleepImpact.score} '
        '(${p.sleepImpact.severity.label.toLowerCase()}). '
        '${Formatters.duration(night)} of usage landed after 10pm and your peak '
        'screen hour was around $peak.\n\n'
        'Tonight, try:\n'
        '• Set a "phone outside bedroom" alarm 45 minutes before bed.\n'
        '• Switch to greyscale after dinner.\n'
        '• If you wake at night, leave the phone where it is — most pickups '
        'are habit, not need.';
  }

  String _loopAdvice(Prediction p, DailyUsage t) {
    final culprits =
        t.apps
            .where(
              (a) =>
                  a.category.isDistracting &&
                  a.opens >= 10 &&
                  a.averageSessionMinutes < 4,
            )
            .toList()
          ..sort((a, b) => b.opens.compareTo(a.opens));
    if (culprits.isEmpty) {
      return 'No clear dopamine loop in today\'s data — you opened apps '
          'thoughtfully on average. Want help building on that?';
    }
    final worst = culprits.first;
    return 'You opened ${worst.appName} ${worst.opens} times in sessions '
        'averaging ${worst.averageSessionMinutes.toStringAsFixed(1)}m — '
        'a textbook dopamine loop.\n\nThree-step reset:\n'
        '1. Move ${worst.appName} to the second screen and into a folder.\n'
        '2. Mute all notifications for 24 hours.\n'
        '3. Add a 10-second pause: every time you open it, breathe once before scrolling.';
  }

  String _burnoutAdvice(Prediction p) {
    return 'Burnout risk is ${p.burnoutRisk.score} '
        '(${p.burnoutRisk.severity.label.toLowerCase()}). Recovery beats '
        'more discipline. Try blocking one screen-free evening this week and '
        'treat it like an appointment.';
  }

  String _modelAdvice(String text) {
    final isTextTask = _match(text, [
      'chat',
      'question',
      'text',
      'nlp',
      'llm',
      'rag',
      'summar',
      'assistant',
    ]);
    final isImageTask = _match(text, [
      'image',
      'vision',
      'photo',
      'object detect',
      'ocr',
    ]);
    final isSmallData = _match(text, [
      'small dataset',
      'few rows',
      'tiny dataset',
      'limited data',
    ]);

    final buffer =
        StringBuffer()
          ..writeln(
            'If you want to train a model on your dataset, start with the task type, not the model name:',
          )
          ..writeln(
            '1. Define the target: classification, regression, ranking, text, image, or time series.',
          )
          ..writeln(
            '2. Clean the data: remove duplicates, fix labels, handle missing values, and split train/validation/test.',
          )
          ..writeln(
            '3. Build a baseline first, then improve it with tuning and better features.',
          )
          ..writeln(
            '4. Measure the right metric for the task, then check for leakage and overfitting.',
          )
          ..writeln(
            '5. Export and monitor the model after deployment, because the data will drift.',
          )
          ..writeln('');

    if (isTextTask) {
      buffer.writeln(
        'For text or chat tasks, choose a small LLM if you need speed or on-device use, like Phi-3.5 Mini or Llama 3.1 8B; for API-backed chat, larger models give better reasoning.',
      );
      buffer.writeln(
        'If your goal is question answering over your own documents, use RAG before fine-tuning unless you need the model to learn a new style or behavior.',
      );
    } else if (isImageTask) {
      buffer.writeln(
        'For image tasks, start with a pretrained vision model such as ResNet, EfficientNet, or ViT, then fine-tune on your labels.',
      );
      buffer.writeln(
        'If you have limited data, transfer learning is usually better than training from scratch.',
      );
    } else if (isSmallData) {
      buffer.writeln(
        'For a small dataset, choose a simpler model first: logistic regression, random forest, XGBoost, or a small pretrained model.',
      );
      buffer.writeln(
        'Avoid large models unless you have enough data to support them.',
      );
    } else {
      buffer.writeln(
        'If the data is tabular, start with XGBoost or LightGBM because they are strong baselines and easy to tune.',
      );
      buffer.writeln(
        'If you need deep learning, only move there after the baseline is beaten and the problem really needs it.',
      );
    }

    buffer.writeln('');
    buffer.writeln(
      'Short answer: choose the simplest model that matches your task and data size, then fine-tune only after a baseline works.',
    );
    buffer.write(
      'If you want, I can also help you pick a model for a specific dataset if you tell me the task, data type, and number of samples.',
    );

    return buffer.toString();
  }

  String _limitAdvice(DailyUsage t) {
    final over = t.totalMinutes - dailyLimit;
    if (over <= 0) {
      return 'You\'re still ${Formatters.duration(-over)} under your '
          '${Formatters.duration(dailyLimit)} goal — nicely done.';
    }
    return 'You\'re ${Formatters.duration(over)} past your '
        '${Formatters.duration(dailyLimit)} goal. A 20-minute walk without '
        'the phone is the simplest reset.';
  }

  String _fallback(Prediction p, DailyUsage t) {
    return 'I can help with focus, sleep, dopamine loops, screen-time goals, '
        'or general AI and model questions. Try one of the quick prompts '
        'below, or ask me about your dataset, task type, and sample size.';
  }
}

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final List<_CoachMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late _CoachBrain _brain;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _brain = _CoachBrain(
      prediction: state.prediction,
      today: state.todayUsage,
      firstName: state.firstName,
      dailyLimit: state.dailyLimitMinutes,
    );
    _messages.add(
      _CoachMessage(
        fromBot: true,
        text: _brain.greeting(),
        time: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(
        _CoachMessage(fromBot: false, text: trimmed, time: DateTime.now()),
      );
    });
    _input.clear();
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _CoachMessage(
            fromBot: true,
            text: _brain.reply(trimmed),
            time: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.calmGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Wellness coach', style: theme.textTheme.titleMedium),
                Text(
                  'Personalised · on-device',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _Bubble(message: _messages[i]),
            ),
          ),
          _QuickPrompts(prompts: _brain.quickPrompts(), onTap: _send),
          _Composer(controller: _input, onSend: () => _send(_input.text)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBot = message.fromBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isBot ? theme.colorScheme.surface : AppTheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 4 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 4),
          ),
          border: isBot ? Border.all(color: theme.dividerColor) : null,
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isBot ? theme.colorScheme.onSurface : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.prompts, required this.onTap});

  final List<String> prompts;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final prompt = prompts[i];
          return ActionChip(
            label: Text(prompt),
            onPressed: () => onTap(prompt),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Ask about focus, sleep, or your loops…',
                ),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
