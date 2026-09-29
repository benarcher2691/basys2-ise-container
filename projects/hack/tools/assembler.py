#!/usr/bin/env python3
# Hack assembler (nand2tetris project 6), written by Ben in 2013.
# Usage: python3 tools/assembler.py prog.asm   ->  writes prog.hack next to it
# (one 16-bit binary word per line, the format hack_rom.v reads).

import sys

def convert2bin15(n):
	b = bin(int(n))[2:]
	return '0' * (15 - len(b)) + b

class Parser:
	temp = []
	result = []
	currentCommand = -1
	
	def __init__(self, fin, sym):
		self.pass1(fin, sym)
		self.pass2(sym)
		
	def pass1(self, fin, sym):
		address = 0
		for line in fin:
			if '//' in line:
				line = line[:line.find('//')]
			line = line.strip()
			line.replace(' ', '')
			if line != '':
				if '(' in line:
					label = line[1 + line.find('('):line.find(')')]
					sym.addEntry(label, address)
				else:	
					address += 1
					self.temp.append(line)	
	
	def pass2(self, sym):
		nextAddress = 16
		for line in self.temp:
			if '@' in line:
				commandType = 'A'
				symbol = line[1:]
				if  not symbol.isdigit():
					if sym.contains(symbol):
						symbol = sym.getAddress(symbol)
					else:
						sym.addEntry(symbol, str(nextAddress))
						symbol = sym.getAddress(symbol)
						nextAddress += 1	
				dst = ''
				cmp = ''
				jmp = ''
			elif '=' in line and ';' in line:
				commandType = 'C'
				dst = line[:line.find('=')]
				cmp = line[1+(line.find('=')):line.find(';')]
				jmp = line[1+ (line.find(';')):]
			elif '=' in line:
				commandType = 'C'
				dst = line[:line.find('=')]
				cmp = line[1+(line.find('=')):]
				jmp = 'null'
			else:
				commandType = 'C'
				dst = 'null'
				cmp = line[:line.find(';')]
				jmp = line[1+ (line.find(';')):]
		
			self.result.append((commandType, symbol, dst, cmp, jmp))			
	
	def hasMoreCommands(self):
		return len(self.result) > 0 and self.currentCommand +1 < len(self.result)
	
	def advance(self):
		self.currentCommand += 1
	
	def commandType(self):
		return self.result[self.currentCommand][0]
	
	def symbol(self):
		return self.result[self.currentCommand][1]	
	
	def dest(self):
		return self.result[self.currentCommand][2]	
	
	def comp(self):
		return self.result[self.currentCommand][3]	
	
	def jump(self):
		return self.result[self.currentCommand][4]
	
class Code:
	cmp = 	{	'0'		:	'0101010',
						'1'		:	'0111111',
    				'-1'	:	'0111010',
    				'D'		:	'0001100',
    				'A'		:	'0110000',
    				'M'		:	'1110000',
    				'!D'	:	'0001101',
    				'!A'	:	'0110001',
    				'!M'	:	'1110001',
    				'-D'	:	'0001111',
    				'-A'	:	'0110011',
    				'-M'	:	'1110011',
    				'D+1'	:	'0011111',
    				'A+1'	:	'0110111',
    				'M+1'	:	'1110111',
    				'D-1'	:	'0001110',
    				'A-1'	:	'0110010',
    				'M-1'	:	'1110010',
    				'D+A'	:	'0000010',
    				'D+M'	:	'1000010',
    				'D-A'	:	'0010011',
    				'D-M'	:	'1010011',
    				'A-D'	:	'0000111',
    				'M-D'	:	'1000111',
    				'D&A'	:	'0000000',
    				'D&M'	:	'1000000',
    				'D|A'	:	'0010101',
    				'D|M'	:	'1010101'
					}

	jmp = 	{	'null'	:	'000',
							'JGT'	:	'001',
							'JEQ'	:	'010',
							'JGE'	:	'011',
							'JLT'	:	'100',
							'JNE'	:	'101',
							'JLE'	:	'110',
							'JMP'	:	'111'
					}

	dst = 	{	'null'	:	'000',
							'M'		:	'001',
							'D'		:	'010',
							'MD'	:	'011',
							'A'		:	'100',
							'AM'	:	'101',
							'AD'	:	'110',
							'AMD'	:	'111'
					}

	def dest(self, mnemonic):
		return self.dst[mnemonic]

	def comp(self, mnemonic):
		return self.cmp[mnemonic]

	def jump(self, mnemonic):
		return self.jmp[mnemonic]

	
class SymbolTable:
	sym = 	{	'SP'	:	'0',
						'LCL'	:	'1',
						'ARG'	:	'2',
						'THIS'	:	'3',
						'THAT'	:	'4',
						'R0'	:	'0',
						'R1'	:	'1',
						'R2'	:	'2',
						'R3'	:	'3',
						'R4'	:	'4',
						'R5'	:	'5',
						'R6'	:	'6',
						'R7'	:	'7',
						'R8'	:	'8',
						'R9'	:	'9',
						'R10'	:	'10',
						'R11'	:	'11',
						'R12'	:	'12',
						'R13'	:	'13',
						'R14'	:	'14',
						'R15'	:	'15',
						'SCREEN':	'16384',
						'KBD'	:	'24576'
					}
				
	def addEntry(self, symbol, address):
		self.sym[symbol] = address
		
	def contains(self, symbol):
		return (symbol in self.sym)
		
	def getAddress(self, symbol):
		return self.sym[symbol]				

fi = open(sys.argv[1], 'r')
fo = open((sys.argv[1])[:-3] + 'hack', 'w')

c = Code()
s = SymbolTable()
parser = Parser(fi, s)

while parser.hasMoreCommands():
	parser.advance()
	if parser.commandType() == 'A':
		prelude = '0'
		fo.write(prelude + convert2bin15(parser.symbol()) + '\n')
	else:
		dst = parser.dest()
		cmp = parser.comp()
		jmp = parser.jump()
		prelude = '111'
		fo.write(prelude + c.comp(cmp) + c.dest(dst) + c.jump(jmp) + '\n')