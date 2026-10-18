package com.example.librarymanagmentsystem.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class RequestLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return request.getRequestURI().startsWith("/actuator");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long start = System.nanoTime();
        try {
            chain.doFilter(request, response);
        } finally {
            long millis = (System.nanoTime() - start) / 1_000_000;
            int status = response.getStatus();
            if (status >= 500) {
                log.error("{} {} {} {}ms", request.getMethod(), request.getRequestURI(), status, millis);
            } else if (status >= 400) {
                log.warn("{} {} {} {}ms", request.getMethod(), request.getRequestURI(), status, millis);
            } else {
                log.info("{} {} {} {}ms", request.getMethod(), request.getRequestURI(), status, millis);
            }
        }
    }
}
