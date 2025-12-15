package com.example.englishankiapp

class AnkiApiException(
    val code: String,
    override val message: String,
    val details: Any? = null,
) : RuntimeException(message)

