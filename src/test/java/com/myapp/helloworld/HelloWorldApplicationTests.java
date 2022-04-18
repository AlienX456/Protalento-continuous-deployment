package com.myapp.helloworld;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment= SpringBootTest.WebEnvironment.RANDOM_PORT)
class HelloWorldApplicationTests {


    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void ifCallGetHello_ThenReturnHelloWord() {
        String body = this.restTemplate.getForObject("/get-hello", String.class);
        assertThat(body).isEqualTo("Hello World! Protalento!!");
    }

}
