#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++
#

module WorkPackages::Scopes
  class ForScheduling
    class << self
      def fetch(work_packages)
        # TODO: try to get rid of this
        return [] if work_packages.empty?

        values = work_packages.map { |wp| "(#{wp.id},#{wp.id},'{#{wp.id}}'::int[])" }.join(', ')

        sql = <<~SQL
          WITH RECURSIVE paths(from_id, last_joined_id, path) AS (
            SELECT * FROM (VALUES#{values}) AS t(from_id, last_joined_id, path)
            UNION ALL
                     SELECT
                      CASE
                      WHEN to_relations.to_id = paths.from_id
                      THEN to_relations.from_id
                      ELSE to_relations.to_id
                      END from_id,
                      CASE
                      WHEN to_relations.to_id = paths.from_id
                      THEN to_relations.to_id
                      ELSE to_relations.from_id
                      END last_joined_id,
                      CASE
                      WHEN to_relations.to_id = paths.from_id
                      THEN array_append(path, to_relations.from_id)
                      ELSE array_append(path, to_relations.to_id)
                      END final_path
                    FROM paths
                    JOIN relations to_relations
                    ON (to_relations.to_id = paths.from_id AND to_relations.from_id != paths.last_joined_id AND "to_relations"."relates" = 0 AND "to_relations"."duplicates" = 0 AND "to_relations"."blocks" = 0 AND "to_relations"."includes" = 0 AND "to_relations"."requires" = 0
                      AND (to_relations.hierarchy + to_relations.relates + to_relations.duplicates + to_relations.follows + to_relations.blocks + to_relations.includes + to_relations.requires = 1))
                      OR (to_relations.from_id = paths.from_id AND to_relations.to_id != paths.last_joined_id AND "to_relations"."follows" = 0 AND "to_relations"."relates" = 0 AND "to_relations"."duplicates" = 0 AND "to_relations"."blocks" = 0 AND "to_relations"."includes" = 0 AND "to_relations"."requires" = 0
                      AND (to_relations.hierarchy + to_relations.relates + to_relations.duplicates + to_relations.follows + to_relations.blocks + to_relations.includes + to_relations.requires = 1))
                    ), manually AS (
                      SELECT from_id from paths
                      JOIN work_packages ON work_packages.id = paths.from_id
                      WHERE work_packages.schedule_manually = true
                    ), manual_by_hierarchy AS (
                      SELECT
                        relations.from_id
                      FROM
                        manually
                      LEFT JOIN relations
                        ON manually.from_id = relations.to_id AND  "relations"."follows" = 0 AND "relations"."relates" = 0 AND "relations"."duplicates" = 0 AND "relations"."blocks" = 0 AND "relations"."includes" = 0 AND "relations"."requires" = 0
                        AND (relations.hierarchy + relations.relates + relations.duplicates + relations.follows + relations.blocks + relations.includes + relations.requires != 0)
                      WHERE relations.from_id IS NOT NULL
                    ), manual_by_path AS (
                SELECT
                        paths.from_id, manually.from_id manual_id
                      FROM
                      paths
                      JOIN manually
                      ON manually.from_id = any(paths.path)
              ), leafs_in_path AS (
                SELECT paths.from_id id
                FROM paths
                LEFT JOIN	relations
                        ON paths.from_id = relations.from_id AND "relations".hierarchy = 1 AND "relations"."follows" = 0 AND "relations"."relates" = 0 AND "relations"."duplicates" = 0 AND "relations"."blocks" = 0 AND "relations"."includes" = 0 AND "relations"."requires" = 0
                        AND (relations.hierarchy + relations.relates + relations.duplicates + relations.follows + relations.blocks + relations.includes + relations.requires = 1)
                WHERE relations.from_id IS NULL
              ), automatic_in_hierarchy_and_path AS (
                SELECT
                      paths.from_id id, paths.path, manual_by_path.manual_id
                    FROM
                    paths
                    LEFT JOIN relations
              ON paths.from_id = relations.from_id AND relations.to_id IN (SELECT id FROM leafs_in_path) AND "relations"."follows" = 0 AND "relations"."relates" = 0 AND "relations"."duplicates" = 0 AND "relations"."blocks" = 0 AND "relations"."includes" = 0 AND "relations"."requires" = 0
                        AND (relations.hierarchy + relations.relates + relations.duplicates + relations.follows + relations.blocks + relations.includes + relations.requires != 0)
              LEFT JOIN manual_by_path
                      ON manual_by_path.from_id = relations.to_id OR (manual_by_path.from_id = paths.from_id AND manual_by_path.manual_id IS NOT NULL)
              )

              SELECT DISTINCT work_packages.*
              FROM automatic_in_hierarchy_and_path
              JOIN work_packages ON work_packages.id = automatic_in_hierarchy_and_path.id
              WHERE manual_id IS NULL
              AND work_packages.id NOT IN (#{work_packages.map(&:id).join(',')})
        SQL

        WorkPackage.find_by_sql(sql)
      end
    end
  end
end
