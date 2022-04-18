package com.myapp.helloworld.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloWorldController {

    @GetMapping("/get-hello")
    public String getHello() {
        return "Hello World! Pro Talento!";
    }

}
