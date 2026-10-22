package com.pandora.log.mapper;

import java.time.OffsetDateTime;
import java.util.List;

import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import com.pandora.log.entity.User;

@Mapper
public interface UserMapper {

    String COLUMNS = "id, username, password_hash, real_name, role_code, department_id, team_id, "
            + "status, failed_attempts, locked_until, created_at, updated_at";

    @Select("SELECT " + COLUMNS + " FROM users WHERE username = #{username}")
    User findByUsername(@Param("username") String username);

    @Select("SELECT " + COLUMNS + " FROM users WHERE id = #{id}")
    User findById(@Param("id") Long id);

    @Select("SELECT COUNT(*) FROM users WHERE role_code = #{roleCode}")
    long countByRole(@Param("roleCode") String roleCode);

    @Select("SELECT " + COLUMNS + " FROM users WHERE role_code = #{roleCode} ORDER BY id")
    List<User> findByRole(@Param("roleCode") String roleCode);

    @Insert("INSERT INTO users (username, password_hash, real_name, role_code, department_id, team_id, "
            + "status, failed_attempts) VALUES (#{username}, #{passwordHash}, #{realName}, #{roleCode}, "
            + "#{departmentId}, #{teamId}, #{status}, #{failedAttempts})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(User user);

    @Update("UPDATE users SET failed_attempts = #{failedAttempts}, locked_until = #{lockedUntil}, "
            + "updated_at = now() WHERE id = #{id}")
    int updateLoginFailure(@Param("id") Long id,
            @Param("failedAttempts") int failedAttempts,
            @Param("lockedUntil") OffsetDateTime lockedUntil);

    @Update("UPDATE users SET failed_attempts = 0, locked_until = NULL, updated_at = now() WHERE id = #{id}")
    int clearLoginFailures(@Param("id") Long id);
}
