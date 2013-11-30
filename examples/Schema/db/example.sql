CREATE TABLE "artist" (
  "artistid" INTEGER PRIMARY KEY NOT NULL,
  "name" text NOT NULL
);

CREATE UNIQUE INDEX "artist_name" ON "artist" ("name");

CREATE TABLE "cd" (
  "cdid" INTEGER PRIMARY KEY NOT NULL,
  "artist" integer NOT NULL,
  "title" text NOT NULL,
  "year" datetime,
  FOREIGN KEY ("artist") REFERENCES "artist"("artistid") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "cd_idx_artist" ON "cd" ("artist");

CREATE UNIQUE INDEX "cd_title_artist" ON "cd" ("title", "artist");

CREATE TABLE "track" (
  "trackid" INTEGER PRIMARY KEY NOT NULL,
  "cd" integer NOT NULL,
  "title" text NOT NULL,
  FOREIGN KEY ("cd") REFERENCES "cd"("cdid") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "track_idx_cd" ON "track" ("cd");

CREATE UNIQUE INDEX "track_title_cd" ON "track" ("title", "cd");
