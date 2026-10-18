package com.pandora.log.mapper;

import java.util.List;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface PermissionMapper {

    @Select("SELECT permission_code FROM role_permissions WHERE role_code = #{roleCode} ORDER BY permission_code")
    List<String> findPermissionCodesByRole(@Param("roleCode") String roleCode);
}
