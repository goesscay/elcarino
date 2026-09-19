import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/section_row.dart';

/// docs/07-ui-ux-design.md §3.5 "Edit profile": "Sections: photos, prompts,
/// bio, basics, relationship goal, interests. Each opens a focused editor."
/// Bio/basics/relationship goal are combined into one "Basics & bio" editor
/// here rather than three single-field screens — they're the same PUT
/// /profiles/me call either way, and splitting them into three destinations
/// added IA complexity with no functional benefit. A disclosed
/// simplification, same spirit as the OTP-field / photo-reorder-buttons ones
/// from the onboarding feature.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            'Choose a section to edit. Changes show on your profile straight away.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            children: [
              SectionRow(
                icon: Icons.photo_library_outlined,
                title: 'Photos',
                subtitle: 'Add, remove and reorder',
                onTap: () => context.push('/profile/edit/photos'),
              ),
              SectionRow(
                icon: Icons.person_outline,
                title: 'Basics & bio',
                subtitle: 'Name, birthday, gender, about me, goals',
                onTap: () => context.push('/profile/edit/basics'),
              ),
              SectionRow(
                icon: Icons.interests_outlined,
                title: 'Interests',
                subtitle: 'What you’re into',
                onTap: () => context.push('/profile/edit/interests'),
              ),
              SectionRow(
                icon: Icons.chat_bubble_outline,
                title: 'Prompts',
                subtitle: 'Conversation starters',
                onTap: () => context.push('/profile/edit/prompts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
