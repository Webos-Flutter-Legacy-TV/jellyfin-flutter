// The browser preview keeps images in the browser's own cache.
import 'package:flutter/painting.dart';

ImageProvider cachedImage(String url) => NetworkImage(url);
