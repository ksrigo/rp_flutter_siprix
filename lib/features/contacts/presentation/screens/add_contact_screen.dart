import 'package:flutter/material.dart';

import '../widgets/contact_form.dart';

class AddContactScreen extends StatelessWidget {
  final String? prefilledPhone;
  
  const AddContactScreen({
    super.key,
    this.prefilledPhone,
  });

  @override
  Widget build(BuildContext context) {
    return ContactForm(
      prefilledPhone: prefilledPhone,
      onSaved: () => Navigator.of(context).pop(),
    );
  }
}