import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/contact_picker_view_model.dart';

/// 联系人选择 ViewModel Provider
final contactPickerViewModelProvider =
    NotifierProvider<ContactPickerViewModel, ContactPickerState>(
      ContactPickerViewModel.new,
    );
