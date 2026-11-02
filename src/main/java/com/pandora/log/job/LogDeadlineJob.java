package com.pandora.log.job;

import com.pandora.log.service.LogDeadlineService;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.log-deadline-job.enabled", havingValue = "true", matchIfMissing = true)
public class LogDeadlineJob {
    private final LogDeadlineService service;
    public LogDeadlineJob(LogDeadlineService service) { this.service = service; }

    @Scheduled(fixedDelayString = "${app.log-deadline-job.interval-ms:60000}",
            initialDelayString = "${app.log-deadline-job.initial-delay-ms:1000}")
    public void run() { service.settle(); }
}
