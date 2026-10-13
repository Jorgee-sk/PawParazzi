package com.pawparazzi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class PawparazziBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(PawparazziBackendApplication.class, args);
    }
}
