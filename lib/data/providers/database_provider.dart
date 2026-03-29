import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database_helper.dart';

final Provider<DatabaseHelper> databaseHelperProvider =
    Provider<DatabaseHelper>((Ref ref) => DatabaseHelper.instance);
