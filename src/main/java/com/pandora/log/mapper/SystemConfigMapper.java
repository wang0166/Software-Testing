package com.pandora.log.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface SystemConfigMapper {

    @Select("SELECT value FROM system_configs WHERE key = #{key}")
    String findValue(@Param("key") String key);
}
