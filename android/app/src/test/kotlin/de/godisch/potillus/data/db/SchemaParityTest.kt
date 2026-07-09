/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.data.db

// =============================================================================
// SchemaParityTest.kt – the database schema is a cross-platform contract
// =============================================================================
//
// `test-vectors/db-schema.json` is GENERATED FROM this module's authoritative
// Room schema export. The iOS suite builds a real database with GRDB and
// introspects it against that contract; this test guards the other end of the
// wire: that the Room export still says what the contract says.
//
// WHY THIS IS NOT CIRCULAR
//   The vector file is a snapshot, committed once. If someone changes a Room
//   entity, Room regenerates `schemas/<version>.json` and THIS test fails,
//   forcing a conscious decision: either the schema change is intended — then the
//   contract is regenerated and the iOS side updated in the same commit — or it
//   was accidental. Without this check, Android could evolve the schema and iOS
//   would keep building a database that no longer matches, with nothing red.
//
// WHY NOT OPEN A REAL DATABASE HERE
//   Room needs an Android runtime; opening one in a plain JVM unit test would
//   pull in Robolectric or move the check to an instrumented test. The exported
//   schema is Room's own machine-generated description of what it *will* build,
//   which is exactly the artefact worth comparing.
// =============================================================================

import de.godisch.potillus.domain.SharedTestVectors
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SchemaParityTest {

    private companion object {
        val CONTRACT: JSONObject = SharedTestVectors.load("db-schema")

        /** The app module directory, per the project's test-path convention. */
        private val MODULE_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override) else File(".")
        }

        private val SCHEMA_DIR = File(MODULE_DIR, "schemas/de.godisch.potillus.data.db.AppDatabase")

        /** Room's export for the version the contract pins. */
        val ROOM_SCHEMA: JSONObject = run {
            val version = CONTRACT.getInt("schemaVersion")
            val file = File(SCHEMA_DIR, "$version.json")
            check(file.isFile) { "Room schema export not found: ${file.absolutePath}" }
            JSONObject(file.readText()).getJSONObject("database")
        }

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }

        /** The Room entity for [table], or null when the table is absent. */
        fun entity(table: String): JSONObject? =
            ROOM_SCHEMA.getJSONArray("entities").objects().firstOrNull {
                it.getString("tableName") == table
            }
    }

    @Test
    fun `exported schema version matches the contract`() {
        assertEquals(CONTRACT.getInt("schemaVersion"), ROOM_SCHEMA.getInt("version"))
    }

    @Test
    fun `every contract table exists with the right columns`() {
        CONTRACT.getJSONArray("tables").objects().forEach { table ->
            val name = table.getString("name")
            val room = entity(name) ?: error("Room schema has no table '$name'")

            val roomFields = room.getJSONArray("fields").objects()
                .associateBy { it.getString("columnName") }
            val wanted = table.getJSONArray("columns").objects().toList()

            assertEquals("$name: column count", wanted.size, roomFields.size)

            wanted.forEach { column ->
                val columnName = column.getString("name")
                val field = roomFields[columnName] ?: error("$name: missing column '$columnName'")
                assertEquals(
                    "$name.$columnName: affinity",
                    column.getString("type"), field.getString("affinity"),
                )
                assertEquals(
                    "$name.$columnName: notNull",
                    column.getBoolean("notNull"), field.getBoolean("notNull"),
                )
            }
        }
    }

    @Test
    fun `primary keys and autoincrement match the contract`() {
        CONTRACT.getJSONArray("tables").objects().forEach { table ->
            val name = table.getString("name")
            val room = entity(name) ?: error("Room schema has no table '$name'")
            val pk = room.getJSONObject("primaryKey")

            assertEquals(
                "$name: primary key columns",
                table.getJSONArray("primaryKey").strings(),
                pk.getJSONArray("columnNames").strings(),
            )
            assertEquals(
                "$name: autoGenerate",
                table.getBoolean("autoIncrement"),
                pk.optBoolean("autoGenerate", false),
            )
            if (table.getBoolean("autoIncrement")) {
                // Room spells autoGenerate as AUTOINCREMENT in the DDL it emits;
                // ids are then never reused after a delete.
                assertTrue(
                    "$name: expected AUTOINCREMENT in createSql",
                    room.getString("createSql").uppercase().contains("AUTOINCREMENT"),
                )
            }
        }
    }

    @Test
    fun `indices match the contract`() {
        CONTRACT.getJSONArray("tables").objects().forEach { table ->
            val name = table.getString("name")
            val room = entity(name) ?: error("Room schema has no table '$name'")
            val roomIndices = room.optJSONArray("indices")?.objects()?.associateBy {
                it.getString("name")
            } ?: emptyMap()

            table.getJSONArray("indices").objects().forEach { index ->
                val indexName = index.getString("name")
                val roomIndex = roomIndices[indexName] ?: error("$name: missing index '$indexName'")
                assertEquals(
                    "index $indexName: columns",
                    index.getJSONArray("columns").strings(),
                    roomIndex.getJSONArray("columnNames").strings(),
                )
                assertEquals(
                    "index $indexName: unique",
                    index.getBoolean("unique"), roomIndex.getBoolean("unique"),
                )
            }
        }
    }

    @Test
    fun `foreign keys match the contract`() {
        CONTRACT.getJSONArray("tables").objects().forEach { table ->
            val name = table.getString("name")
            val room = entity(name) ?: error("Room schema has no table '$name'")
            val roomFks = room.optJSONArray("foreignKeys")?.objects()?.toList() ?: emptyList()
            val wanted = table.getJSONArray("foreignKeys").objects().toList()

            assertEquals("$name: foreign-key count", wanted.size, roomFks.size)

            wanted.forEach { fk ->
                val column = fk.getString("column")
                val roomFk = roomFks.firstOrNull {
                    it.getJSONArray("columns").strings() == listOf(column)
                } ?: error("$name: missing foreign key on '$column'")

                assertEquals(fk.getString("referencesTable"), roomFk.getString("table"))
                assertEquals(
                    listOf(fk.getString("referencesColumn")),
                    roomFk.getJSONArray("referencedColumns").strings(),
                )
                // RESTRICT, not CASCADE: deleting a drink that still has entries
                // must fail loudly rather than erase the user's history.
                assertEquals(
                    "$name.$column: onDelete",
                    fk.getString("onDelete"), roomFk.getString("onDelete"),
                )
                assertEquals(
                    "$name.$column: onUpdate",
                    fk.getString("onUpdate"), roomFk.getString("onUpdate"),
                )
            }
        }
    }
}
