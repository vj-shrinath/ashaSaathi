// Communicable Disease Register (#idsp) is a DYNAMIC conditional form, not a
// fixed field list. This file defines the 16 diseases (5 quick-access
// priority chips + 11 grouped in a categorized dropdown) and which fields to
// show once a disease is selected. Mirrors the reference demo's `idspDiseases`.

class IdspDisease {
  final String key;
  final String label;
  final String group; // 'priority' or a category name for the dropdown
  final String fieldSet; // 'tb' | 'leprosy' | 'vector' | 'other'

  const IdspDisease({
    required this.key,
    required this.label,
    required this.group,
    required this.fieldSet,
  });
}

const List<IdspDisease> kIdspDiseases = [
  IdspDisease(key: 'malaria', label: 'Î Malaria', group: 'priority', fieldSet: 'vector'),
  IdspDisease(key: 'dengue', label: '8 Dengue', group: 'priority', fieldSet: 'vector'),
  IdspDisease(key: 'tb', label: 'y TB', group: 'priority', fieldSet: 'tb'),
  IdspDisease(key: 'leprosy', label: '“ Leprosy', group: 'priority', fieldSet: 'leprosy'),
  IdspDisease(key: 'typhoid', label: 'S Typhoid / Diarrhea', group: 'priority', fieldSet: 'other'),
  IdspDisease(key: 'covid', label: 'COVID-19', group: 'Respiratory / Airborne', fieldSet: 'other'),
  IdspDisease(key: 'flu', label: 'Influenza (Flu)', group: 'Respiratory / Airborne', fieldSet: 'other'),
  IdspDisease(key: 'measles', label: 'Measles (गोवर)', group: 'Respiratory / Airborne', fieldSet: 'other'),
  IdspDisease(key: 'diphtheria', label: 'Diphtheria (घटसप )', group: 'Respiratory / Airborne', fieldSet: 'other'),
  IdspDisease(key: 'pertussis', label: 'Pertussis (डांग्या खोकला)', group: 'Respiratory / Airborne', fieldSet: 'other'),
  IdspDisease(key: 'cholera', label: 'Cholera (कॉलरा)', group: 'Water & Food Borne', fieldSet: 'other'),
  IdspDisease(key: 'hepatitisae', label: 'Hepatitis A/E', group: 'Water & Food Borne', fieldSet: 'other'),
  IdspDisease(key: 'chikungunya', label: 'Chikungunya', group: 'Vector-Borne', fieldSet: 'vector'),
  IdspDisease(key: 'rabies', label: 'Rabies', group: 'Animal Bite', fieldSet: 'other'),
  IdspDisease(key: 'hivaids', label: 'HIV/AIDS', group: 'Blood-borne / STI', fieldSet: 'other'),
  IdspDisease(key: 'hepatitisbc', label: 'Hepatitis B/C', group: 'Blood-borne / STI', fieldSet: 'other'),
];

List<IdspDisease> get kIdspPriorityChips =>
    kIdspDiseases.where((d) => d.group == 'priority').toList();

Map<String, List<IdspDisease>> get kIdspDropdownGroups {
  final map = <String, List<IdspDisease>>{};
  for (final d in kIdspDiseases.where((d) => d.group != 'priority')) {
    map.putIfAbsent(d.group, () => []).add(d);
  }
  return map;
}

class IdspFieldDef {
  final String id;
  final String label;
  final String kind; // 'text' | 'pill2' | 'yesno'
  
  const IdspFieldDef({
    required this.id, 
    required this.label, 
    required this.kind,
  });
}

List<IdspFieldDef> idspFieldsFor(String fieldSet) {
  switch (fieldSet) {
    case 'tb':
      return const [
        IdspFieldDef(id: 'nikshayid', label: 'Nikshay ID', kind: 'text'),
        IdspFieldDef(id: 'sputumdate', label: 'Sputum Test Date', kind: 'text'),
        IdspFieldDef(id: 'dotsstatus', label: 'DOTS Status', kind: 'text'),
        IdspFieldDef(id: 'nikshaypmy', label: 'Nikshay Poshan DBT Link', kind: 'text'),
      ];
    case 'leprosy':
      return const [
        IdspFieldDef(id: 'nlepid', label: 'NLEP ID', kind: 'text'),
        IdspFieldDef(id: 'skinpatchdate', label: 'Skin Patch Screening Date', kind: 'text'),
      ];
    case 'vector':
      return const [
        IdspFieldDef(id: 'testdate', label: 'Blood Slide / RDT Test Date', kind: 'text'),
        IdspFieldDef(id: 'testoutcome', label: 'Test Outcome', kind: 'pill2'),
      ];
    default: // 'other'
      return const [
        IdspFieldDef(id: 'onsetdate', label: 'Date of Onset', kind: 'text'),
        IdspFieldDef(id: 'contacttracing', label: 'Family Contact Tracing Status', kind: 'yesno'),
        IdspFieldDef(id: 'outbreakflag', label: 'PHC Outbreak Alert Flag', kind: 'yesno'),
      ];
  }
}
