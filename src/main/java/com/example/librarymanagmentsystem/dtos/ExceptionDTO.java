package com.example.librarymanagmentsystem.dtos;
import lombok.NoArgsConstructor;


import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class ExceptionDTO {
    private String message;
    private String resoultion;
}
