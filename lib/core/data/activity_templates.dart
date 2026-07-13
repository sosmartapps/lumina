import 'package:flutter/material.dart';

import '../models/reminder.dart';

/// A curated "purposeful activity" the caregiver can add to the patient's
/// day with one tap. Based on Montessori-method dementia care: familiar,
/// meaningful tasks maintain skills, increase engagement, and reduce
/// agitation (see docs/cognitive-engagement-research.md).
///
/// Templates instantiate ordinary [Reminder] docs, so the entire existing
/// pipeline — TTS popup, photo capture, dHash match, Claude-vision
/// verification, caregiver override — works unchanged.
class ActivityTemplate {
  final String id;
  final String title;
  final String description;

  /// Warm TTS message; `{name}` is replaced with the patient's name.
  final String spokenMessage;
  final ReminderType type;
  final IconData icon;
  final String iconName;
  final String category;

  /// One line for the caregiver: why this activity helps.
  final String benefit;
  final int suggestedHour;
  final int suggestedMinute;
  final bool suggestPhoto;
  final bool homeOnly;

  const ActivityTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.spokenMessage,
    this.type = ReminderType.task,
    required this.icon,
    required this.iconName,
    required this.category,
    required this.benefit,
    required this.suggestedHour,
    this.suggestedMinute = 0,
    this.suggestPhoto = true,
    this.homeOnly = true,
  });

  TimeOfDay get suggestedTime =>
      TimeOfDay(hour: suggestedHour, minute: suggestedMinute);
}

/// Category display order.
const activityCategories = <String>[
  'Around the House',
  'Kitchen & Meals',
  'Plants & Outdoors',
  'Creative & Senses',
  'Self-Care',
];

const activityTemplates = <ActivityTemplate>[
  // ---- Around the House ----
  ActivityTemplate(
    id: 'fold_laundry',
    title: 'Fold the laundry',
    description: 'Fold towels or clothes and stack them neatly',
    spokenMessage:
        '{name}, when you have a moment, the laundry is ready to be '
        'folded. Take your time — stack it nice and neat.',
    icon: Icons.checkroom,
    iconName: 'checkroom',
    category: 'Around the House',
    benefit: 'Familiar repetitive motion; keeps hands busy and calms nerves',
    suggestedHour: 10,
  ),
  ActivityTemplate(
    id: 'make_bed',
    title: 'Make the bed',
    description: 'Pull up the covers and arrange the pillows',
    spokenMessage:
        'Good morning {name}! Let\'s start the day by making the bed — '
        'pull up the covers and set the pillows in place.',
    icon: Icons.bed,
    iconName: 'bed',
    category: 'Around the House',
    benefit: 'Anchors the morning routine with an easy early win',
    suggestedHour: 8,
    suggestedMinute: 30,
  ),
  ActivityTemplate(
    id: 'sort_socks',
    title: 'Sort and match socks',
    description: 'Match the socks into pairs',
    spokenMessage:
        '{name}, there\'s a basket of socks that need matching. '
        'See how many pairs you can find!',
    icon: Icons.join_full,
    iconName: 'join_full',
    category: 'Around the House',
    benefit: 'A satisfying, familiar sorting activity',
    suggestedHour: 14,
  ),
  ActivityTemplate(
    id: 'tidy_table',
    title: 'Tidy the living room table',
    description: 'Straighten up the magazines, coasters, and remote controls',
    spokenMessage:
        '{name}, could you tidy up the living room table? '
        'Everything in its place.',
    icon: Icons.cleaning_services,
    iconName: 'cleaning_services',
    category: 'Around the House',
    benefit: 'A purposeful role in keeping the household nice',
    suggestedHour: 16,
  ),

  // ---- Kitchen & Meals ----
  ActivityTemplate(
    id: 'set_table',
    title: 'Set the table for dinner',
    description: 'Put out the plates, glasses, forks, and napkins',
    spokenMessage:
        '{name}, dinner is coming up — could you set the table? '
        'Plates, glasses, forks, and napkins.',
    icon: Icons.table_restaurant,
    iconName: 'table_restaurant',
    category: 'Kitchen & Meals',
    benefit: 'A meaningful part in the family mealtime routine',
    suggestedHour: 17,
    suggestedMinute: 30,
  ),
  ActivityTemplate(
    id: 'prepare_snack',
    title: 'Prepare a simple snack',
    description: 'Make a small snack — fruit, crackers, or a sandwich',
    spokenMessage:
        '{name}, how about a little snack? Fix yourself something '
        'simple — some fruit or crackers sound good.',
    icon: Icons.lunch_dining,
    iconName: 'lunch_dining',
    category: 'Kitchen & Meals',
    benefit: 'Encourages independence in the kitchen',
    suggestedHour: 15,
  ),
  ActivityTemplate(
    id: 'dry_dishes',
    title: 'Dry and put away the dishes',
    description: 'Dry the clean dishes and stack them on the counter',
    spokenMessage:
        '{name}, the dishes are clean and ready to be dried. '
        'Stack them on the counter when you\'re done.',
    icon: Icons.countertops,
    iconName: 'countertops',
    category: 'Kitchen & Meals',
    benefit: 'A familiar, hands-on lifelong routine',
    suggestedHour: 19,
  ),

  // ---- Plants & Outdoors ----
  ActivityTemplate(
    id: 'water_plants',
    title: 'Water the plants',
    description: 'Give each plant a drink of water',
    spokenMessage:
        '{name}, the plants are thirsty! Could you give each one '
        'a drink of water?',
    icon: Icons.local_florist,
    iconName: 'local_florist',
    category: 'Plants & Outdoors',
    benefit: 'Caring for living things builds purpose and routine',
    suggestedHour: 9,
  ),
  ActivityTemplate(
    id: 'short_walk',
    title: 'Take a short walk',
    description: 'A gentle 10-minute walk, inside or outside',
    spokenMessage:
        '{name}, it\'s a lovely time for a short walk. '
        'Ten minutes will feel wonderful.',
    type: ReminderType.exercise,
    icon: Icons.directions_walk,
    iconName: 'directions_walk',
    category: 'Plants & Outdoors',
    benefit: 'Gentle movement and fresh air as part of the day',
    suggestedHour: 10,
    suggestedMinute: 30,
    suggestPhoto: false,
    homeOnly: false,
  ),
  ActivityTemplate(
    id: 'sweep_porch',
    title: 'Sweep the porch or patio',
    description: 'Give the porch or patio a quick sweep',
    spokenMessage:
        '{name}, the porch could use a quick sweep when you '
        'have a minute.',
    icon: Icons.cleaning_services_outlined,
    iconName: 'cleaning_services',
    category: 'Plants & Outdoors',
    benefit: 'Light whole-body movement with a visible result',
    suggestedHour: 11,
  ),

  // ---- Creative & Senses ----
  ActivityTemplate(
    id: 'arrange_flowers',
    title: 'Arrange flowers in a vase',
    description: 'Arrange fresh or artificial flowers in a vase',
    spokenMessage:
        '{name}, there are flowers ready to be arranged. '
        'Make them look beautiful!',
    icon: Icons.yard,
    iconName: 'yard',
    category: 'Creative & Senses',
    benefit: 'A sensory-rich creative activity many find uplifting',
    suggestedHour: 13,
  ),
  ActivityTemplate(
    id: 'draw_color',
    title: 'Draw or color a picture',
    description: 'Spend some time drawing or coloring',
    spokenMessage:
        '{name}, your colors and paper are ready — draw or color '
        'anything you like.',
    icon: Icons.palette,
    iconName: 'palette',
    category: 'Creative & Senses',
    benefit: 'Creative expression without right-or-wrong answers',
    suggestedHour: 14,
    suggestedMinute: 30,
  ),
  ActivityTemplate(
    id: 'photo_album',
    title: 'Look through a photo album',
    description: 'Enjoy some family photos for a while',
    spokenMessage:
        '{name}, the photo album is out on the table. '
        'Enjoy some good memories.',
    icon: Icons.photo_album,
    iconName: 'photo_album',
    category: 'Creative & Senses',
    benefit: 'A comforting way to revisit good memories',
    suggestedHour: 15,
    suggestedMinute: 30,
    suggestPhoto: false,
  ),
  ActivityTemplate(
    id: 'listen_music',
    title: 'Listen to favorite music',
    description: 'Sit back and enjoy some favorite songs',
    spokenMessage:
        '{name}, it\'s music time! Put on some of your favorite '
        'songs and enjoy.',
    icon: Icons.music_note,
    iconName: 'music_note',
    category: 'Creative & Senses',
    benefit: 'Familiar favorite songs are calming and enjoyable',
    suggestedHour: 16,
    suggestedMinute: 30,
    suggestPhoto: false,
  ),

  // ---- Self-Care ----
  ActivityTemplate(
    id: 'brush_pet',
    title: 'Brush the pet',
    description: 'Give the pet a gentle brushing',
    spokenMessage:
        '{name}, your furry friend would love a good brushing!',
    type: ReminderType.petCare,
    icon: Icons.pets,
    iconName: 'pets',
    category: 'Self-Care',
    benefit: 'Quiet time with a pet in a caring role',
    suggestedHour: 11,
    suggestedMinute: 30,
  ),
  ActivityTemplate(
    id: 'tidy_nightstand',
    title: 'Tidy the nightstand',
    description: 'Arrange the things on the bedside table',
    spokenMessage:
        '{name}, could you neaten up your nightstand? '
        'Everything easy to reach for tonight.',
    icon: Icons.nightlight,
    iconName: 'nightlight',
    category: 'Self-Care',
    benefit: 'Ownership of personal space; calm end-of-day ritual',
    suggestedHour: 19,
    suggestedMinute: 30,
  ),
];
