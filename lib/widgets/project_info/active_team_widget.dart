import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';

class ActiveTeamCard extends StatelessWidget {
  final List<User> activeMembers;

  const ActiveTeamCard({super.key, required this.activeMembers});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('현재 투입 인력',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${activeMembers.length}',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface)),
                        const SizedBox(width: 4),
                        Text('명 작업중',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people_outlined,
                    size: 20, color: Colors.purple.shade600),
              ),
            ],
          ),
          SizedBox(
            height: 40,
            child: activeMembers.isEmpty
                ? Text('작업 중인 팀원 없음',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)))
                : Stack(
                    children: [
                      ...List.generate(
                        min(activeMembers.length, 5),
                        (i) {
                          final member = activeMembers[i];
                          return Positioned(
                            left: i * 28.0,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade400,
                                    Colors.indigo.shade500,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: member.profileImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                            member.profileImageUrl!,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover))
                                    : Text(
                                        member.username.isNotEmpty
                                            ? member.username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (activeMembers.length > 5)
                        Positioned(
                          left: 5 * 28.0,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Center(
                              child: Text(
                                '+${activeMembers.length - 5}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
