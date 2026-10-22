package com.pandora.log.common;

public record PageQuery(int page, int size) {

    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_SIZE = 100;

    public static PageQuery of(Integer page, Integer size) {
        int resolvedPage = page == null || page < 1 ? 1 : page;
        int resolvedSize = size == null || size < 1
                ? DEFAULT_SIZE
                : Math.min(size, MAX_SIZE);
        return new PageQuery(resolvedPage, resolvedSize);
    }

    public long offset() {
        return (long) (page - 1) * size;
    }
}
