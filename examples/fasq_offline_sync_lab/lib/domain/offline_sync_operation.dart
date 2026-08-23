class ReplayOutcome {
  const ReplayOutcome({
    required this.executedCount,
    required this.blockedCount,
  });

  final int executedCount;
  final int blockedCount;
}
