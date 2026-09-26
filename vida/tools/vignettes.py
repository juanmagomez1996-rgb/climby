#!/usr/bin/env python3
"""Prompts de las viñetas de cada carta (ev_<id>). Imprime JSON para generate_image_batch."""
import json, sys
REF = {0: 'c3760cd5-7f4c-40be-97fb-b9e3f1238a70', 1: 'b6f189cc-956d-4ad6-83cd-6cc9c5d29626', 2: 'f6dd23e6-ba14-4b8f-90de-347d24c14cf1',
       3: '4f8c085b-448c-46c2-877d-c7d3bae81d49', 4: 'ccaa5e90-a81f-4ee0-89ae-55fb91b39d45'}
FAM = 'c35360f0-998c-490d-827d-7bec48a2a164'
STYLE = ('Wide storybook vignette illustration in exactly the same hand-painted gouache and colored pencil style as the reference images, '
         'clean brown outlines, warm nostalgic palette, soft paper grain, simple uncluttered composition centered on the characters, '
         'the main character Ramón looks exactly like the reference (same big round rosy nose, same outfit). No text, no letters, no words, no speech bubbles. Scene: ')
V = [  # id, etapa, familia?, escena
 ('cole', 0, 0, 'first day of school, little Ramón stands in a sunny classroom with a school backpack, choosing between an empty seat by the window and a seat next to a quirky boy eating glue from a jar'),
 ('diente', 0, 0, 'little Ramón in pajamas grinning with a gap in his teeth, holding up a tiny tooth, a pillow behind him'),
 ('tardes', 0, 0, 'little Ramón at home after school looking at three options: a football, a small piano, and a game console, afternoon light'),
 ('hamster', 0, 0, 'little Ramón carefully carrying a small cage with a chubby classroom hamster'),
 ('bici', 0, 0, 'little Ramón on a small bicycle without training wheels, wobbling, the training wheels lying on the ground'),
 ('lentejas', 0, 0, 'little Ramón in a school canteen staring suspiciously at a plate of lentil stew, a paper napkin next to it'),
 ('campamento', 0, 0, 'little Ramón with a big backpack in front of a summer camp with tents and pine trees'),
 ('pelo', 1, 0, 'teen Ramón looking in a bathroom mirror holding a box of electric blue hair dye'),
 ('banda', 1, 0, 'teen Ramón in a garage with friends and music instruments, drums, an electric guitar, amplifier'),
 ('examen', 1, 0, 'teen Ramón at his desk at night with textbooks, looking at his phone showing a party invitation, a window with city lights'),
 ('lucia', 1, 1, 'teen Ramón nervously holding a small park flower behind his back, a teenage girl with long wavy dark-auburn hair (like the reference woman Lucía, but 17 years old) at a school gate'),
 ('heladeria', 1, 0, 'teen Ramón wearing a striped apron and paper hat behind the counter of a colorful ice cream shop'),
 ('carnet', 1, 0, 'teen Ramón gripping the steering wheel of a small driving school car, a nervous examiner with a clipboard in the passenger seat'),
 ('insti', 1, 0, 'teen Ramón at a crossroads signpost with three paths: a university building, a carpet shop, and a road to the mountains with a backpack'),
 ('perro', 2, 1, 'adult Ramón at his front door at dusk, a scruffy small tan and white dog with one floppy ear (Tornillo, like the reference dog) looking up at him hopefully'),
 ('gimnasio', 2, 0, 'adult Ramón in a gym in sports clothes looking unsure at a treadmill, a January calendar on the wall'),
 ('viaje', 2, 0, 'adult Ramón looking at a travel poster of northern lights over snowy mountains in a travel agency window'),
 ('boda', 2, 1, 'adult Ramón and the woman Lucía from the reference in a sunny garden, she holds his hands and smiles, a ring box between them'),
 ('app', 2, 0, 'adult Ramón at a cafe table looking at his phone with a dating app heart, a cup of coffee, waiting'),
 ('piso', 2, 0, 'adult Ramón holding a set of keys in front of a small apartment building with a for sale sign without text'),
 ('hijos', 2, 1, 'adult Ramón and Lucía from the reference on a sofa, looking at a baby crib and a potted plant, thoughtful and tender'),
 ('plantavecina', 2, 0, 'adult Ramón on a staircase landing receiving a big leafy potted plant from an elderly neighbor with moving boxes'),
 ('reunion', 2, 0, 'adult Ramón in a video meeting on a laptop at home, many tiny faces on screen, the clock showing almost seven'),
 ('mudanza', 2, 0, 'adult Ramón sweating while carrying one end of a big sofa up a narrow staircase with a friend'),
 ('ascenso', 2, 0, 'adult Ramón in an office facing his boss, a woman offering a golden key, a calendar with weekends crossed out behind'),
 ('funcion', 2, 1, 'a school stage where little girl Alba from the reference is dressed as a tree in a school play, adult Ramón in the audience filming with his phone'),
 ('crisis', 2, 0, 'adult Ramón at 40 standing between a shiny red motorcycle and a pair of running shoes, looking in a mirror at a grey hair'),
 ('cunado', 3, 0, 'middle-aged Ramón at a family dinner, his enthusiastic brother-in-law showing him a tablet with a chart going up, a bowl of potatoes on the table'),
 ('tatuaje', 3, 1, 'middle-aged Ramón and teenage Alba from the reference outside a colorful tattoo studio'),
 ('analitica', 3, 0, 'middle-aged Ramón in a doctor office, the doctor handing him a lab test sheet, a stethoscope'),
 ('huerto', 3, 0, 'middle-aged Ramón with a straw hat in a small backyard vegetable garden holding a big ugly tomato proudly'),
 ('antiguos', 3, 0, 'middle-aged Ramón at a restaurant reunion with old classmates, all balding, raising glasses'),
 ('croquetas', 3, 0, 'middle-aged Ramón at a table with a plate of golden croquettes, a doctor wagging a finger next to him'),
 ('prejubila', 3, 0, 'middle-aged Ramón in an office with cardboard boxes, looking at a beach postcard'),
 ('bodahija', 3, 1, 'middle-aged Ramón dancing clumsily with adult Alba in a wedding dress from the reference, happy guests, fairy lights'),
 ('nieto', 3, 1, 'middle-aged Ramón holding a newborn baby wrapped in a blanket, adult Alba from the reference smiling next to him'),
 ('jubila', 4, 0, 'old Ramón with his cane watching a construction site through a fence with other retirees, hands behind his back'),
 ('aquagym', 4, 0, 'old Ramón in a swimming cap and flotation noodle at a public pool aquagym class with other seniors'),
 ('tablet', 4, 0, 'old Ramón holding a tablet close to his face, confused but curious, on a sofa'),
 ('baile', 4, 0, 'old Ramón at a senior center dance, a disco ball, elderly couples dancing pasodoble'),
 ('bingo', 4, 0, 'old Ramón at a bingo hall with three bingo cards and a marker, a cured ham as the prize on a shelf'),
 ('amigo', 4, 0, 'old Ramón at his kitchen table reading a handwritten letter, an old photo of two boys next to it, an old telephone'),
 ('memorias', 4, 0, 'old Ramón writing in a notebook at a desk full of old photographs, a lamp at night'),
 ('ahorros', 4, 0, 'old Ramón sitting on his bed with an old mattress, a piggy bank, a cruise ship brochure and gift envelopes'),
 ('parejamuere', 4, 1, 'old Ramón alone on a bench by the sea at sunset holding a small photo of old Lucía from the reference, a cardigan on the empty seat'),
]
start, end = int(sys.argv[1]), int(sys.argv[2])
reqs = []
for i, (id_, st, fam, sc) in enumerate(V[start:end], start):
    med = [{'value': REF[st], 'role': 'image_references'}] + ([{'value': FAM, 'role': 'image_references'}] if fam else [])
    reqs.append({'index': i, 'params': {'model': 'nano_banana_2', 'aspect_ratio': '16:9', 'medias': med, 'prompt': STYLE + sc}})
print(json.dumps(reqs, ensure_ascii=False))
if len(sys.argv) > 3: print(json.dumps([v[0] for v in V]))
