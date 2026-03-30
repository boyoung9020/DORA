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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.people_outlined,
                size: 16, color: Colors.purple.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('현재 투입 인력',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${activeMembers.length}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface)),
                    const SizedBox(width: 3),
                    Text('명 작업중',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 26,
            child: activeMembers.isEmpty
                ? Text('작업 중인 팀원 없음',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)))
                : Stack(
                    children: [
                      ...List.generate(
                        min(activeMembers.length, 5),
                        (i) {
                          final member = activeMembers[i];
                          return Positioned(
                            left: i * 19.0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
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
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.cover))
                                    : Text(
                                        member.username.isNotEmpty
                                            ? member.username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (activeMembers.length > 5)
                        Positioned(
                          left: 5 * 19.0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '+${activeMembers.length - 5}',
                                style: TextStyle(
                                    fontSize: 9,
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
