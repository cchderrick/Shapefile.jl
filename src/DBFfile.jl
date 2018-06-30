# Field Descriptor Type Structure
struct FieldDescriptorType
    FieldName::String
    FieldType::Char
    FieldDataAddress
    FieldLength::UInt8
    DecimalCount::Int8
    #ReservedForMultiUserdBASE1819
    WorkAreaID
    #ReservedForMultiUserdBASE2122
    FlagForSET_FIELDS
    #Reserved
    IndexFieldFlag
end

# Field Descriptor Type Reader
function Base.read(io::IO,::Type{FieldDescriptorType})
    # Field Descriptor Array
    fieldName = String(read(io,UInt8,11))
    fieldType = Char(read(io,UInt8))
    fieldDataAddress = read(io,UInt32)
    fieldLength = read(io,UInt8)
    decimalCount = read(io,UInt8)
    reservedForMultiUserdBASE1819 = read(io,UInt8,2) #Not saved
    workAreaID = read(io,UInt8)
    reservedForMultiUserdBASE2122 = read(io,UInt8,2) #Not saved
    flagForSET_FIELDS = read(io,UInt8)
    reserved = read(io,UInt8,7)
    indexFieldFlag = read(io,UInt8)  #Not saved
    return FieldDescriptorType(
        fieldName, fieldType, fieldDataAddress, fieldLength, decimalCount,
        workAreaID, flagForSET_FIELDS, indexFieldFlag)
end

# Read a DBF field according to a Field Decriptor
function Base.read(io::IO,thisField::FieldDescriptorType)
    rec_ = read(io,UInt8,thisField.FieldLength)
    
    if (thisField.FieldType == 'C')
        
        return strip(String(rec_))

    elseif (thisField.FieldType == 'N' || thisField.FieldType == 'F')
        
        return parse(String(rec_))

    elseif (thisField.FieldType == 'L')
        
        boolChar = Char(rec_)
        return any(boolChar.==['Y','y','t','T'])

    elseif (thisField.FieldType == 'D')

        dateStr = String(rec_)
        return Date( 
                parse(dateStr[1:4]),
                parse(dateStr[5:6]), 
                parse(dateStr[7:8]) )

    else

        # Return raw UInt8 array for unknown type
        # return Dict( fieldname => rec_)
        return rec_

    end
    
end

# Read an array of DBF field by an array of FieldDescriptorType
function Base.read(io::IO,fieldDescriptorArray::Array{FieldDescriptorType})
    return [read(io,thisField) for thisField = fieldDescriptorArray]
end

# DBF File Header
struct DBFHeader
    VersionNumber
    LastUpdate
    NumberOfRecords::Int
    LengthOfHeaders
    LengthOfEachRec
    #Reserved
    IncompleteTransac
    EncryptionFlag
    FreeRecord
    #Reserved2
    MDXFlag
    LanguageDriver
    #Reserved3
    FieldDescriptorArray::Array{FieldDescriptorType}
    Records
end

#  DBF File Header
function Base.read(io::IO,::Type{DBFHeader})
    version_number = read(io,UInt8)
    last_update = read(io,UInt8,3)
    number_of_records = read(io,UInt32)
    length_of_headers = read(io,UInt16)
    length_of_each_rec = read(io,UInt16)
    reserved = read(io,UInt8,2) #Not saved
    incomplete_transac = read(io,UInt8)
    encryption_flag = read(io,UInt8)
    free_record = read(io,UInt8,4)
    reserved = read(io,UInt8,8) #Not saved
    MDX_flag = read(io,UInt8)
    language_driver = read(io,UInt8)
    reserved = read(io,UInt8,2) #Not saved

    fieldDescriptorArray = FieldDescriptorType[];
    push!(fieldDescriptorArray, read(io,FieldDescriptorType))
    while Base.peek(io)!=0x0d
        push!(fieldDescriptorArray, read(io,FieldDescriptorType))
    end
    @assert read(io,UInt8)==0x0d
    # Finish reading header and field descriptors
    
    # Begin reading the individual records
    records = []
    while !eof(io)
        DeletedFlag = read(io,UInt8)
        if DeletedFlag!=0x2A
            push!(records, read(io,fieldDescriptorArray))
        end
    end
    close(io)

    # Extrac the field names
    return DBFHeader(
        version_number,
        last_update,
        number_of_records,
        length_of_headers,
        length_of_each_rec,
        incomplete_transac,
        encryption_flag,
        free_record,
        MDX_flag,
        language_driver,
        fieldDescriptorArray,
        records)

end