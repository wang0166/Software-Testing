package com.pandora.log.mapper;

import java.time.OffsetDateTime;

import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import com.pandora.log.entity.RefreshToken;

@Mapper
public interface RefreshTokenMapper {

    String COLUMNS = "id, user_id, token_hash, expires_at, revoked_at, created_at";

    @Insert("INSERT INTO refresh_tokens (user_id, token_hash, expires_at) "
            + "VALUES (#{userId}, #{tokenHash}, #{expiresAt})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(RefreshToken token);

    @Select("SELECT " + COLUMNS + " FROM refresh_tokens WHERE token_hash = #{tokenHash}")
    RefreshToken findByTokenHash(@Param("tokenHash") String tokenHash);

    @Update("UPDATE refresh_tokens SET revoked_at = #{revokedAt} WHERE id = #{id} AND revoked_at IS NULL")
    int revokeById(@Param("id") Long id, @Param("revokedAt") OffsetDateTime revokedAt);

    @Update("UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = #{tokenHash} AND revoked_at IS NULL")
    int revokeByTokenHash(@Param("tokenHash") String tokenHash);
}
