package com.example.englishankiapp

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri

class AnkiProviderClient(private val context: Context) {
    private val resolver: ContentResolver get() = context.contentResolver

    private val deckNameCache = HashMap<Long, String>()
    private val modelFieldNameCache = HashMap<Long, List<String>>()

    fun getStatus(): Map<String, Any?> {
        val installed = isAnkiDroidInstalled()
        val providerVisible = isAnkiProviderVisible()

        if (!installed) {
            return mapOf(
                "installed" to false,
                "providerVisible" to providerVisible,
                "providerAccessible" to false,
                "lastErrorCode" to "ANKI_NOT_INSTALLED",
                "lastErrorMessage" to "AnkiDroid is not installed",
            )
        }

        if (!providerVisible) {
            return mapOf(
                "installed" to true,
                "providerVisible" to false,
                "providerAccessible" to false,
                "lastErrorCode" to "ANKI_PROVIDER_NOT_FOUND",
                "lastErrorMessage" to "AnkiDroid ContentProvider not visible. Check Android 11+ <queries>.",
            )
        }

        return try {
            // Use notes_v2 with a trivial query to verify provider access without heavy work.
            val cursor = resolver.query(notesV2Uri, arrayOf("_id"), "1=0", null, null)
            if (cursor == null) {
                return mapOf(
                    "installed" to true,
                    "providerVisible" to true,
                    "providerAccessible" to false,
                    "lastErrorCode" to "ANKI_NULL_CURSOR",
                    "lastErrorMessage" to "Provider returned null cursor. Try opening AnkiDroid once and retry.",
                )
            }
            cursor.close()
            mapOf(
                "installed" to true,
                "providerVisible" to true,
                "providerAccessible" to true,
                "lastErrorCode" to null,
                "lastErrorMessage" to null,
            )
        } catch (e: SecurityException) {
            mapOf(
                "installed" to true,
                "providerVisible" to true,
                "providerAccessible" to false,
                "lastErrorCode" to "ANKI_PERMISSION_DENIED",
                "lastErrorMessage" to "SecurityException: ${e.message}",
            )
        } catch (e: Throwable) {
            mapOf(
                "installed" to true,
                "providerVisible" to true,
                "providerAccessible" to false,
                "lastErrorCode" to "ANKI_QUERY_FAILED",
                "lastErrorMessage" to e.toString(),
            )
        }
    }

    fun getDecks(): List<Map<String, Any?>> {
        if (!isAnkiDroidInstalled()) {
            throw AnkiApiException(
                code = "ANKI_NOT_INSTALLED",
                message = "AnkiDroid is not installed",
            )
        }

        if (!isAnkiProviderVisible()) {
            throw AnkiApiException(
                code = "ANKI_PROVIDER_NOT_FOUND",
                message = "AnkiDroid ContentProvider not found. Check AndroidManifest <queries>.",
            )
        }

        val projection = arrayOf("deck_id", "deck_name", "deck_count")
        return try {
            val cursor = resolver.query(decksUri, projection, null, null, null) ?: return emptyList()
            cursor.use {
                val idIdx = it.getColumnIndexOrNull("deck_id")
                    ?: throw AnkiApiException(
                        code = "ANKI_SCHEMA_MISMATCH",
                        message = "Unexpected decks schema (missing deck_id).",
                        details = it.columnNames.toList(),
                    )
                val nameIdx = it.getColumnIndexOrNull("deck_name")
                    ?: throw AnkiApiException(
                        code = "ANKI_SCHEMA_MISMATCH",
                        message = "Unexpected decks schema (missing deck_name).",
                        details = it.columnNames.toList(),
                    )
                val countIdx = it.getColumnIndexOrNull("deck_count")

                val decks = ArrayList<Map<String, Any?>>()
                while (it.moveToNext()) {
                    val deckId = it.getLong(idIdx)
                    val deckName = it.getString(nameIdx) ?: ""
                    val rawCounts = countIdx?.let(it::getString)
                    val counts = parseDeckCounts(rawCounts)
                    decks.add(
                        mapOf(
                            "deckId" to deckId,
                            "deckName" to deckName,
                            "newCount" to counts?.newCount,
                            "learnCount" to counts?.learnCount,
                            "reviewCount" to counts?.reviewCount,
                        )
                    )
                }

                decks
            }
        } catch (e: SecurityException) {
            throw AnkiApiException(
                code = "ANKI_PERMISSION_DENIED",
                message = "AnkiDroid provider access denied (SecurityException). Open AnkiDroid once and verify API/permissions.",
                details = e.message,
            )
        } catch (e: Throwable) {
            throw AnkiApiException(
                code = "ANKI_QUERY_FAILED",
                message = "Failed to query decks from AnkiDroid provider.",
                details = e.toString(),
            )
        }
    }

    fun getTodayNewCards(deckId: Long, limit: Int): List<Map<String, Any?>> {
        val safeLimit = limit.coerceIn(0, 1000)
        val safeDeckId = deckId.coerceAtLeast(0L)

        if (!isAnkiDroidInstalled()) {
            throw AnkiApiException(
                code = "ANKI_NOT_INSTALLED",
                message = "AnkiDroid is not installed",
            )
        }

        if (!isAnkiProviderVisible()) {
            throw AnkiApiException(
                code = "ANKI_PROVIDER_NOT_FOUND",
                message = "AnkiDroid ContentProvider not found. Check AndroidManifest <queries>.",
            )
        }

        if (safeDeckId <= 0L) {
            throw AnkiApiException(
                code = "INVALID_ARGUMENT",
                message = "deckId is required",
            )
        }

        if (safeLimit == 0) return emptyList()

        val notes = queryNewNotesByDeck(deckId = safeDeckId, limit = safeLimit)

        val result = ArrayList<Map<String, Any?>>(notes.size)
        val deckName = getDeckName(safeDeckId) ?: "Unknown Deck"
        for (note in notes) {
            val fieldNames = getModelFieldNames(note.modelId)
            val fieldValues = splitFields(note.fldsRaw)

            val fields = ArrayList<Map<String, String>>(fieldValues.size)
            for ((index, value) in fieldValues.withIndex()) {
                val name = fieldNames?.getOrNull(index) ?: "Field ${index + 1}"
                fields.add(mapOf("name" to name, "value" to value))
            }

            val frontText = fieldValues.firstOrNull()
                ?.takeIf { it.isNotBlank() }
                ?: note.sortField
                ?: ""

            result.add(
                mapOf(
                    "cardId" to note.noteId.toString(),
                    "modelId" to note.modelId,
                    "deckName" to deckName,
                    "frontText" to frontText,
                    "backFields" to fields,
                )
            )
        }

        return result
    }

    fun openAnkiDroid(): Boolean {
        if (!isAnkiDroidInstalled()) return false
        val intent = context.packageManager.getLaunchIntentForPackage(ANKI_PACKAGE) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }

    fun openPlayStore(): Boolean {
        val marketUri = Uri.parse("market://details?id=$ANKI_PACKAGE")
        val webUri = Uri.parse("https://play.google.com/store/apps/details?id=$ANKI_PACKAGE")

        return try {
            val intent = Intent(Intent.ACTION_VIEW, marketUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Throwable) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, webUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    private fun queryNewNotesByDeck(deckId: Long, limit: Int): List<NoteRow> {
        val projection = arrayOf("_id", "mid", "flds", "sfld")
        // We use notes_v2 (direct SQL) to filter by deck + "new" card state and to order by
        // card modification time (oldest first).
        //
        // Anki DB schema: cards.did, cards.type, cards.queue, cards.mod, cards.nid, notes.id
        val selection = "id IN (SELECT nid FROM cards WHERE did=? AND type=0 AND queue=0)"
        val selectionArgs = arrayOf(deckId.toString())
        // ORDER BY does not accept selectionArgs in Android's query() API, so embed the numeric deckId.
        val order =
            "(SELECT MIN(mod) FROM cards WHERE cards.nid = notes.id AND did=$deckId AND type=0 AND queue=0) ASC, id ASC"

        try {
            val cursor = resolver.query(notesV2Uri, projection, selection, selectionArgs, order) ?: return emptyList()
            cursor.use {
                val idIdx = it.getColumnIndexOrNull("_id") ?: it.getColumnIndexOrNull("id")
                val midIdx = it.getColumnIndexOrNull("mid")
                val fldsIdx = it.getColumnIndexOrNull("flds")
                val sfldIdx = it.getColumnIndexOrNull("sfld")

                if (idIdx == null || midIdx == null || fldsIdx == null) {
                    throw AnkiApiException(
                        code = "ANKI_SCHEMA_MISMATCH",
                        message = "Unexpected notes schema from provider (missing _id/mid/flds).",
                        details = it.columnNames.toList(),
                    )
                }

                val rows = ArrayList<NoteRow>()
                while (it.moveToNext()) {
                    val noteId = it.getLong(idIdx)
                    val modelId = it.getLong(midIdx)
                    val flds = it.getString(fldsIdx) ?: ""
                    val sfld = sfldIdx?.let(it::getString)
                    if (flds.isBlank()) continue

                    rows.add(
                        NoteRow(
                            noteId = noteId,
                            modelId = modelId,
                            fldsRaw = flds,
                            sortField = sfld,
                        )
                    )

                    if (rows.size >= limit) break
                }
                return rows
            }
        } catch (e: SecurityException) {
            throw AnkiApiException(
                code = "ANKI_PERMISSION_DENIED",
                message = "AnkiDroid provider access denied (SecurityException). Open AnkiDroid once and verify API/permissions.",
                details = e.message,
            )
        } catch (e: Throwable) {
            throw AnkiApiException(
                code = "ANKI_QUERY_FAILED",
                message = "Failed to query new notes by deck.",
                details = e.toString(),
            )
        }
    }

    private fun getDeckName(deckId: Long): String? {
        deckNameCache[deckId]?.let { return it }
        val deckUri = Uri.withAppendedPath(decksUri, deckId.toString())
        val projection = arrayOf("deck_name")
        return try {
            val cursor = resolver.query(deckUri, projection, null, null, null) ?: return null
            cursor.use {
                if (!it.moveToFirst()) return null
                val nameIdx = it.getColumnIndexOrNull("deck_name") ?: return null
                val name = it.getString(nameIdx)?.takeIf { n -> n.isNotBlank() } ?: return null
                deckNameCache[deckId] = name
                name
            }
        } catch (e: Throwable) {
            null
        }
    }

    private fun getModelFieldNames(modelId: Long): List<String>? {
        if (modelId == 0L) return null
        modelFieldNameCache[modelId]?.let { return it }
        val modelUri = Uri.withAppendedPath(modelsUri, modelId.toString())
        val projection = arrayOf("field_names")
        return try {
            val cursor = resolver.query(modelUri, projection, null, null, null) ?: return null
            cursor.use {
                if (!it.moveToFirst()) return null
                val namesIdx = it.getColumnIndexOrNull("field_names") ?: return null
                val raw = it.getString(namesIdx) ?: return null
                val names = splitFields(raw).filter { n -> n.isNotBlank() }
                if (names.isEmpty()) return null
                modelFieldNameCache[modelId] = names
                names
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun splitFields(fldsRaw: String): List<String> {
        // In Anki, note.flds uses Unit Separator (0x1f).
        return fldsRaw.split('\u001f')
    }

    private fun parseDeckCounts(raw: String?): DeckCounts? {
        if (raw.isNullOrBlank()) return null
        val cleaned = raw.trim()
        if (!cleaned.startsWith("[") || !cleaned.endsWith("]")) return null
        return try {
            val parts = cleaned.removePrefix("[").removeSuffix("]").split(",")
            if (parts.size < 3) return null
            val learn = parts[0].trim().toIntOrNull()
            val review = parts[1].trim().toIntOrNull()
            val newCount = parts[2].trim().toIntOrNull()
            if (learn == null || review == null || newCount == null) return null
            DeckCounts(learnCount = learn, reviewCount = review, newCount = newCount)
        } catch (_: Throwable) {
            null
        }
    }

    private fun isAnkiDroidInstalled(): Boolean {
        return try {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(ANKI_PACKAGE, 0)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun isAnkiProviderVisible(): Boolean {
        return try {
            @Suppress("DEPRECATION")
            context.packageManager.resolveContentProvider(AUTHORITY, 0) != null
        } catch (_: Throwable) {
            false
        }
    }

    private fun Cursor.getColumnIndexOrNull(name: String): Int? {
        val idx = getColumnIndex(name)
        return if (idx >= 0) idx else null
    }

    private data class NoteRow(
        val noteId: Long,
        val modelId: Long,
        val fldsRaw: String,
        val sortField: String?,
    )

    private companion object {
        private const val TAG = "AnkiProviderClient"
        private const val ANKI_PACKAGE = "com.ichi2.anki"
        private const val AUTHORITY = "com.ichi2.anki.flashcards"

        private val notesUri: Uri = Uri.parse("content://$AUTHORITY/notes")
        private val notesV2Uri: Uri = Uri.parse("content://$AUTHORITY/notes_v2")
        private val decksUri: Uri = Uri.parse("content://$AUTHORITY/decks")
        private val modelsUri: Uri = Uri.parse("content://$AUTHORITY/models")
    }

    private data class DeckCounts(
        val learnCount: Int,
        val reviewCount: Int,
        val newCount: Int,
    )
}
