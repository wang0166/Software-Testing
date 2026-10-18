package com.pandora.log.common;

import java.util.List;

public record PageResult<T>(long total, int page, int size, List<T> items) {
}
