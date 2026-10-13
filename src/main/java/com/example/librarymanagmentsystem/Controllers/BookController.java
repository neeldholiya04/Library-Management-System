package com.example.librarymanagmentsystem.Controllers;


import com.example.librarymanagmentsystem.models.bookModel.Book;
import com.example.librarymanagmentsystem.models.bookModel.Genre;
import com.example.librarymanagmentsystem.dtos.BookDTO;
import com.example.librarymanagmentsystem.services.bookService.BookService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/book")
public class BookController {
    private final BookService bookService;
    @Autowired
    public BookController(BookService bookService){
        this.bookService= bookService;
    }

    // Get Book by Title
    @GetMapping("title/{title}")
    public Book getBookByTitle(@PathVariable("title") String title) {
        Book book = bookService.getBookByTitle(title);
        return book;

    }

    // Get All Books by Author
    @GetMapping("author/{author}")
    public List<Book> getAllBookByAuthor(@PathVariable("author") String author) {
        List<Book> books= bookService.getAllBookByAuthor(author);
        return books;


    }

    // Get All Books by Genre
    @GetMapping("genre/{genre}")
    public List<Book> getAllBookByGenre(@PathVariable("genre") Genre genre) {
        List<Book> books= bookService.getAllBookByGenre(genre);
        return books;
    }

    // Get All Books
    @GetMapping
    public List<Book> getAllBooks() {
        List<Book> books= bookService.getAllBooks();
        return books;
    }

    // Create a Book
    @PostMapping
    public Book createBook(@RequestBody BookDTO bookDTO) {
        return bookService.createBook(bookDTO);
    }

    // Update a Book
    @PutMapping("/{id}")
    public Book updateBook(@PathVariable("id") Long id, @RequestBody BookDTO bookDTO) {
        Book newBook = bookService.updateBook(id, bookDTO);
        return newBook;
    }

    // Delete a Book
    @DeleteMapping("/{id}")
    public void deleteBook(@PathVariable("id") Long id) {
        bookService.deleteBook(id);
    }
}
