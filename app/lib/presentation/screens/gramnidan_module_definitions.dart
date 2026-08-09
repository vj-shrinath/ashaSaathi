class GramNidanFieldDef {
  final String id;
  final String label;

  const GramNidanFieldDef(this.id, this.label);
}

class GramNidanModuleDef {
  final String id;
  final String title;
  final String icon;
  final List<GramNidanFieldDef> fields;

  const GramNidanModuleDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.fields,
  });
}

class GramNidanModuleDefinitions {
  static const List<GramNidanModuleDef> modules = [
    GramNidanModuleDef(
      id: 'village',
      title: 'Village Survey / Master Household',
      icon: '🏘️',
      fields: [
        GramNidanFieldDef('houseno', 'House No.'),
        GramNidanFieldDef('mukhia', 'Head of Family'),
        GramNidanFieldDef('members', 'Total Members'),
        GramNidanFieldDef('mobile', 'Mobile No.'),
        GramNidanFieldDef('category', 'Category (SC/ST/etc)'),
        GramNidanFieldDef('pmjay', 'Ayushman Card'),
        GramNidanFieldDef('toilet', 'Toilet Facility'),
        GramNidanFieldDef('watersource', 'Drinking Water'),
        GramNidanFieldDef('housetype', 'House Type'),
      ],
    ),
    GramNidanModuleDef(
      id: 'ec',
      title: 'Eligible Couple Register',
      icon: '👪',
      fields: [
        GramNidanFieldDef('couple', 'Couple Name'),
        GramNidanFieldDef('age', 'Age (Wife/Husband)'),
        GramNidanFieldDef('children', 'Total Children'),
        GramNidanFieldDef('youngestchildage', 'Youngest Child Age'),
        GramNidanFieldDef('method', 'FP Method Used'),
      ],
    ),
    GramNidanModuleDef(
      id: 'anc',
      title: 'ANC Register',
      icon: '🤰',
      fields: [
        GramNidanFieldDef('name', 'Mother Name'),
        GramNidanFieldDef('gravida', 'Gravida/Para'),
        GramNidanFieldDef('lmp', 'LMP Date'),
        GramNidanFieldDef('edd', 'Expected Delivery'),
        GramNidanFieldDef('weightkg', 'Weight (kg)'),
        GramNidanFieldDef('bpsys', 'BP Systolic'),
        GramNidanFieldDef('bpdia', 'BP Diastolic'),
        GramNidanFieldDef('hb', 'Hemoglobin (g/dL)'),
        GramNidanFieldDef('urineprotein', 'Urine Protein'),
        GramNidanFieldDef('ifagiven', 'IFA Tablets Given'),
        GramNidanFieldDef('hrp', 'High Risk Pregnancy?'),
      ],
    ),
    GramNidanModuleDef(
      id: 'delivery',
      title: 'Delivery & PNC',
      icon: '🍼',
      fields: [
        GramNidanFieldDef('mothername', 'Mother Name'),
        GramNidanFieldDef('datetime', 'Delivery Date/Time'),
        GramNidanFieldDef('place', 'Delivery Place'),
        GramNidanFieldDef('type', 'Delivery Type'),
        GramNidanFieldDef('babyweight', 'Baby Weight (kg)'),
        GramNidanFieldDef('outcome', 'Outcome'),
        GramNidanFieldDef('pncday1', 'PNC Day 1 Status'),
        GramNidanFieldDef('pph', 'PPH Flag'),
      ],
    ),
    GramNidanModuleDef(
      id: 'hbnc',
      title: 'HBNC Register',
      icon: '🏠',
      fields: [
        GramNidanFieldDef('namewt', 'Baby Name/Weight'),
        GramNidanFieldDef('mothername', 'Mother Name'),
        GramNidanFieldDef('temp', 'Temperature'),
        GramNidanFieldDef('cord', 'Umbilical Cord'),
        GramNidanFieldDef('bf', 'Breastfeeding'),
        GramNidanFieldDef('danger', 'Danger Signs?'),
      ],
    ),
    GramNidanModuleDef(
      id: 'cbac',
      title: 'CBAC (NCD Screening)',
      icon: '🩺',
      fields: [
        GramNidanFieldDef('nameage', 'Name & Age'),
        GramNidanFieldDef('tobacco', 'Tobacco Use'),
        GramNidanFieldDef('alcohol', 'Alcohol Use'),
        GramNidanFieldDef('waist', 'Waist Circumference'),
        GramNidanFieldDef('ncdrisk', 'NCD Risk Score'),
      ],
    ),
    GramNidanModuleDef(
      id: 'ncd',
      title: 'NCD Tracking Register',
      icon: '❤️',
      fields: [
        GramNidanFieldDef('nameage', 'Name & Age'),
        GramNidanFieldDef('condition', 'Known Condition'),
        GramNidanFieldDef('bpreading', 'BP Reading'),
        GramNidanFieldDef('bsl', 'Blood Sugar Level'),
        GramNidanFieldDef('medicine', 'Medicine Compliance'),
      ],
    ),
  ];
}
