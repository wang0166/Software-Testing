package com.pandora.log.security;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.entity.User;
import com.pandora.log.mapper.PermissionMapper;
import com.pandora.log.mapper.UserMapper;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class AuthFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwtService;
    private final UserMapper userMapper;
    private final PermissionMapper permissionMapper;
    private final CurrentUserContext currentUserContext;
    private final SecurityErrorWriter securityErrorWriter;

    public AuthFilter(JwtService jwtService,
            UserMapper userMapper,
            PermissionMapper permissionMapper,
            CurrentUserContext currentUserContext,
            SecurityErrorWriter securityErrorWriter) {
        this.jwtService = jwtService;
        this.userMapper = userMapper;
        this.permissionMapper = permissionMapper;
        this.currentUserContext = currentUserContext;
        this.securityErrorWriter = securityErrorWriter;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith(BEARER_PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }

        try {
            Claims claims = jwtService.parseAccessToken(header.substring(BEARER_PREFIX.length()).trim());
            User user = userMapper.findById(jwtService.extractUserId(claims));
            if (user == null || user.isDisabled()) {
                securityErrorWriter.write(response, ErrorCode.ACCOUNT_DISABLED);
                return;
            }
            if (user.isLockedAt(OffsetDateTime.now())) {
                securityErrorWriter.write(response, ErrorCode.ACCOUNT_LOCKED);
                return;
            }

            Set<String> permissions = new LinkedHashSet<>(
                    permissionMapper.findPermissionCodesByRole(user.getRoleCode()));
            CurrentUser currentUser = new CurrentUser(
                    user.getId(),
                    user.getUsername(),
                    user.getRealName(),
                    user.getRoleCode(),
                    user.getDepartmentId(),
                    user.getTeamId(),
                    permissions);

            List<GrantedAuthority> authorities = new ArrayList<>();
            authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRoleCode()));
            permissions.forEach(code -> authorities.add(new SimpleGrantedAuthority(code)));

            SecurityContextHolder.getContext().setAuthentication(
                    new UsernamePasswordAuthenticationToken(currentUser, null, authorities));
            currentUserContext.set(currentUser);
        } catch (JwtException | IllegalArgumentException exception) {
            SecurityContextHolder.clearContext();
            securityErrorWriter.write(response, ErrorCode.INVALID_TOKEN);
            return;
        }

        try {
            filterChain.doFilter(request, response);
        } finally {
            currentUserContext.clear();
            SecurityContextHolder.clearContext();
        }
    }
}
