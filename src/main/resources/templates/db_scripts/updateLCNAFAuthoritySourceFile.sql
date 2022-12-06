UPDATE ${myuniversity}_${mymodule}.authority_source_file
SET jsonb = '{
               "id": "af045f2f-e851-4613-984c-4bc13430454a",
               "name": "LC Name Authority file (LCNAF)",
               "codes": [
                 "n",
                 "nb",
                 "nr",
                 "no",
                 "ns"
               ],
               "type": "Names",
               "baseUrl": "id.loc.gov/authorities/names/",
               "source": "folio"
             }'
WHERE id = 'af045f2f-e851-4613-984c-4bc13430454a';
