package com.example.librarymanagmentsystem.services.bookService;

import com.example.librarymanagmentsystem.Models.bookModel.Author;
import com.example.librarymanagmentsystem.Models.bookModel.Book;
import com.example.librarymanagmentsystem.Models.bookModel.Genre;
import com.example.librarymanagmentsystem.Repositories.AuthorRepository;
import com.example.librarymanagmentsystem.Repositories.BookRepository;
import com.example.librarymanagmentsystem.dtos.BookDTO;
import com.example.librarymanagmentsystem.exceptions.booksexception.AuthorNotFoundException;
import com.example.librarymanagmentsystem.exceptions.booksexception.BookNotFoundException;
import com.example.librarymanagmentsystem.exceptions.booksexception.GenreNotFoundException;
import com.example.librarymanagmentsystem.services.authorService.AuthorService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LibraryBookService implements BookService {
    private final BookRepository bookRepository;

    private final AuthorService authorService;
    private final AuthorRepository authorRepository;

    public LibraryBookService(BookRepository bookRepository, AuthorService authorService, AuthorRepository authorRepository) {
        this.bookRepository = bookRepository;
        this.authorService = authorService;
        this.authorRepository = authorRepository;
    }

    @Override
    public Book getBookByTitle(String title) throws BookNotFoundException{
        Book book = bookRepository.findByTitle(title);
        if(book==null){
            throw new BookNotFoundException("Invalid Title", title);
        }
        return book;
    }

    @Override
    public List<Book> getAllBookByAuthor(String name) throws AuthorNotFoundException {
        Author author = authorService.getAuthorByName(name);
        List<Book> book = bookRepository.findBookByAuthor(author);
        if(book==null){
            throw new AuthorNotFoundException("Invalid Author", name);
        }
        return book;
    }

    @Override
    public List<Book> getAllBookByGenre(Genre genre) throws GenreNotFoundException {
        List<Book> books = bookRepository.findByGenre(genre);
        if(books==null){
            throw new GenreNotFoundException("Invalid Genre", genre);
        }
        return books;
    }

    @Override

    public List<Book> getAllBooks() {
        List<Book> books = bookRepository.findAll();
        return books;
    }

    @Override
    public Book createBook(BookDTO bookDTO) throws AuthorNotFoundException, GenreNotFoundException{
        Author author = authorService.getAuthorById(bookDTO.getAuthorId());
        if(author==null){
            throw new AuthorNotFoundException();
        }
        Book book1 = new Book(bookDTO.getTitle(), author, bookDTO.getGenre(), bookDTO.getPublicationDate(), bookDTO.getISBN());
        bookRepository.save(book1);
        return book1;
    }


    @Override
    public Book updateBook(Long id, BookDTO bookDTO) {
        Book book = update(id, bookDTO);
        bookRepository.save(book);
        return book;
    }

    @Override

    public void deleteBook(Long id) {
        Book book = bookRepository.findByBookId(id);
        if (book == null) {
            throw new BookNotFoundException("neel", "Book with id " + id + " not found");
        }
        bookRepository.delete(book);
    }

    private Book update(Long id, BookDTO bookDTO) {
        Author author = authorService.getAuthorById(bookDTO.getAuthorId());
        Book existingBook = bookRepository.findById(id).get();
        existingBook.setTitle(bookDTO.getTitle());
        existingBook.setAuthor(author);
        existingBook.setGenre(bookDTO.getGenre());
        existingBook.setPublicationDate(bookDTO.getPublicationDate());
        existingBook.setISBN(bookDTO.getISBN());
        return existingBook;
    }
}
